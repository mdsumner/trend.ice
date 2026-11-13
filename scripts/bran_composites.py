#!/usr/bin/env python3
"""BRAN 5-day composites on the OC-CCI 5-day calendar, Southern Ocean only.

For each composite (starts on day-of-year 1, 6, 11, ... of each year, the
OC-CCI 5-day calendar; mid-date = start + 2) average BRAN daily mixed layer
depth, surface temperature and surface salinity over the composite's days,
south of `--north` (default 48S). Writes one NetCDF per calendar year:

    bran_5day_<year>.nc   dims (time, lat, lon), lon in -180..180,
                          vars mld (m), temp (degC, st_ocean[0]), salt (psu, st_ocean[0]),
                          ndays (days averaged); time = composite start

Reads the /g/data-remapped kerchunk stores (tools/kerchunk_remap.py):

    python3 scripts/bran_composites.py STOREDIR OUTDIR [--years 1997 2025]

STOREDIR holds bluelink-daily-{mld,temp,salt}/kerchunk.
"""
import argparse
import datetime as dt
import os

import numpy as np
import xarray as xr

VARS = {"mld": "mld", "temp": "temp", "salt": "salt"}


def open_store(path):
    import fsspec
    fs = fsspec.filesystem("reference", fo=path, remote_protocol="file")
    return xr.open_dataset(fs.get_mapper(), engine="zarr",
                           backend_kwargs={"consolidated": False}, zarr_format=2,
                           decode_times=True, chunks=None)


def composite_starts(year):
    """OC-CCI 5-day composite start dates in a calendar year"""
    jan1 = dt.date(year, 1, 1)
    ndays = 366 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 365
    return [jan1 + dt.timedelta(days=d) for d in range(0, ndays, 5)]


def surface(da):
    return da.isel(st_ocean=0) if "st_ocean" in da.dims else da


def to_pm180(ds, lon="xt_ocean"):
    x = ds[lon].values
    x2 = ((x + 180.0) % 360.0) - 180.0
    ds = ds.assign_coords({lon: x2}).sortby(lon)
    return ds


def composites_for_year(stores, year, north=-48.0):
    """stores: dict name -> Dataset (Time, [st_ocean,] yt_ocean, xt_ocean)"""
    starts = composite_starts(year)
    out = {}
    nd = []
    for name, ds in stores.items():
        da = surface(ds[VARS[name]])
        da = da.sel(yt_ocean=slice(None, north))
        times = da["Time"].values.astype("datetime64[D]")
        layers = []
        for s in starts:
            e = min(np.datetime64(s) + np.timedelta64(5, "D"), np.datetime64(dt.date(year + 1, 1, 1)))
            idx = np.where((times >= np.datetime64(s)) & (times < e))[0]
            if len(idx) == 0:
                layers.append(None)
                if name == "mld":
                    nd.append(0)
                continue
            m = da.isel(Time=idx).mean("Time", skipna=True).astype("float32")
            layers.append(m)
            if name == "mld":
                nd.append(len(idx))
        ok = [lay for lay in layers if lay is not None]
        if not ok:
            return None
        template = xr.full_like(ok[0], np.nan)
        stack = xr.concat([lay if lay is not None else template for lay in layers], dim="time")
        out[name] = stack.assign_coords(time=np.array(starts, dtype="datetime64[ns]"))
    res = xr.Dataset(out)
    res["ndays"] = ("time", np.array(nd, dtype="int16"))
    res = res.drop_vars([v for v in ["st_ocean", "Time"] if v in res.coords])
    res = to_pm180(res).rename({"xt_ocean": "lon", "yt_ocean": "lat"})
    res["mld"].attrs["units"] = "m"
    res["temp"].attrs["units"] = "degC"
    res["salt"].attrs["units"] = "psu"
    res.attrs["source"] = "BRAN2020 daily (Bluelink), via /g/data-remapped kerchunk stores"
    res.attrs["composite"] = "OC-CCI 5-day calendar: starts doy 1, 6, 11, ...; mid = start + 2"
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("storedir")
    ap.add_argument("outdir")
    ap.add_argument("--years", nargs=2, type=int, default=[1997, 2025])
    ap.add_argument("--north", type=float, default=-48.0)
    a = ap.parse_args()
    os.makedirs(a.outdir, exist_ok=True)
    stores = {n: open_store(os.path.join(a.storedir, f"bluelink-daily-{n}", "kerchunk"))
              for n in VARS}
    tmax = min(ds["Time"].values.max() for ds in stores.values())
    print("BRAN available to", str(tmax)[:10])
    for y in range(a.years[0], a.years[1] + 1):
        f = os.path.join(a.outdir, f"bran_5day_{y}.nc")
        if os.path.exists(f):
            print(y, "exists, skipping")
            continue
        res = composites_for_year(stores, y, a.north)
        if res is None:
            print(y, "no BRAN data")
            continue
        enc = {v: {"zlib": True, "complevel": 4} for v in ["mld", "temp", "salt"]}
        res.to_netcdf(f, engine="h5netcdf", encoding=enc)
        print(y, int((res["ndays"] > 0).sum()), "composites ->", f)


if __name__ == "__main__":
    main()
