## synthetic BRAN-like datasets -> composites_for_year
import importlib.util, numpy as np, pandas as pd, xarray as xr
spec = importlib.util.spec_from_file_location("bc", "scripts/bran_composites.py")
bc = importlib.util.module_from_spec(spec); spec.loader.exec_module(bc)
t = pd.date_range("2015-12-20", "2016-01-20", freq="D")
yt = np.linspace(-75, 75, 151); xt = np.arange(0.5, 360, 1.0); st = np.array([2.5, 7.5])
day = np.arange(len(t), dtype="f4")
mld = xr.Dataset({"mld": (("Time", "yt_ocean", "xt_ocean"), np.broadcast_to(day[:, None, None], (len(t), 151, 360)).copy())},
                 coords={"Time": t, "yt_ocean": yt, "xt_ocean": xt})
temp = xr.Dataset({"temp": (("Time", "st_ocean", "yt_ocean", "xt_ocean"),
                            np.broadcast_to(np.stack([day, day + 100], 1)[:, :, None, None], (len(t), 2, 151, 360)).copy())},
                  coords={"Time": t, "st_ocean": st, "yt_ocean": yt, "xt_ocean": xt})
salt = temp.rename({"temp": "salt"})
r = bc.composites_for_year({"mld": mld, "temp": temp, "salt": salt}, 2016, north=-48)
assert r is not None
assert float(r.lat.max()) <= -48 and float(r.lon.min()) >= -180 and float(r.lon.max()) < 180
assert np.all(np.diff(r.lon.values) > 0)
## first 2016 composite: Jan 1-5 = days 12..16 -> mean 14
assert r.ndays.values[0] == 5 and np.allclose(r.mld.isel(time=0).values, 14)
assert np.allclose(r.temp.isel(time=0).values, 14)        ## surface level, not +100
## Jan 16-20 -> days 27..31 mean 29; Jan 21+ no data -> NaN, ndays 0
assert np.allclose(r.mld.isel(time=3).values, 29)
assert r.ndays.values[4] == 0 and np.all(np.isnan(r.mld.isel(time=4).values))
assert len(bc.composite_starts(2016)) == 74 and len(bc.composite_starts(2015)) == 73
assert str(bc.composite_starts(2015)[55]) == "2015-10-03"
print("bran composites test pass")
