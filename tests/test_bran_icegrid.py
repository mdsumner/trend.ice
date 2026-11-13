import importlib.util, numpy as np, pandas as pd, xarray as xr, subprocess, tempfile, os
spec = importlib.util.spec_from_file_location("bc", "scripts/bran_composites.py")
bc = importlib.util.module_from_spec(spec); spec.loader.exec_module(bc)
t = pd.date_range("2016-01-01", "2016-01-31", freq="D")
yt = np.arange(-74.95, 75, 0.1); xt = np.arange(0.05, 360, 0.1)
lat2 = np.broadcast_to(yt[:, None], (len(yt), len(xt)))
mldv = np.where(lat2 < -60, 50.0, 100.0).astype("f4")
mld = xr.Dataset({"mld": (("Time", "yt_ocean", "xt_ocean"), np.broadcast_to(mldv, (len(t),) + mldv.shape).copy())},
                 coords={"Time": t, "yt_ocean": yt, "xt_ocean": xt})
tv = np.broadcast_to(mldv / 50, (len(t), 1) + mldv.shape).copy()
temp = xr.Dataset({"temp": (("Time", "st_ocean", "yt_ocean", "xt_ocean"), tv)},
                  coords={"Time": t, "st_ocean": [2.5], "yt_ocean": yt, "xt_ocean": xt})
salt = temp.rename({"temp": "salt"})
r = bc.composites_for_year({"mld": mld, "temp": temp, "salt": salt}, 2016)
td = tempfile.mkdtemp(); od = tempfile.mkdtemp()
r.to_netcdf(os.path.join(td, "bran_5day_2016.nc"), engine="h5netcdf")
p = subprocess.run(["Rscript", "scripts/bran_to_icegrid.R", td, od], capture_output=True, text=True)
print(p.stderr[-500:])
f = [x for x in os.listdir(od)][0]
d = pd.read_csv(os.path.join(od, f))
print(d.head(3)); print(sorted(d["mid"].unique())[:3])
assert sorted(d["mid"].unique())[0] == "2016-01-03"
assert set(np.round(d["mld"].dropna().unique())).issubset({50.0, 100.0}) or d["mld"].between(50, 100).all()
print("bran icegrid test pass")
