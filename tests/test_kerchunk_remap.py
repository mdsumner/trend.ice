import os, shutil, subprocess, tempfile, numpy as np, xarray as xr, fsspec
from kerchunk.hdf import SingleHdf5ToZarr
from kerchunk.df import refs_to_dataframe
td = tempfile.mkdtemp()
gdata = os.path.join(td, "gdata")
os.makedirs(os.path.join(gdata, "gb6/BRAN/daily"))
nc = os.path.join(gdata, "gb6/BRAN/daily/ocean_mld_2015_12.nc")
ds = xr.Dataset({"mld": (("time", "yt", "xt"), np.random.rand(31, 40, 60).astype("f4"))},
                coords={"time": np.arange(31), "yt": np.linspace(-80, -40, 40), "xt": np.linspace(0, 359, 60)})
ds.to_netcdf(nc, engine="h5netcdf", encoding={"mld": {"chunksizes": (1, 40, 60), "zlib": True}})
refs = SingleHdf5ToZarr(nc, inline_threshold=100).translate()
url = "https://thredds.nci.org.au/thredds/fileServer/gb6/BRAN/daily/ocean_mld_2015_12.nc"
for k, v in refs["refs"].items():
    if isinstance(v, list) and len(v) == 3:
        refs["refs"][k] = [url, v[1], v[2]]
src = os.path.join(td, "src.parq")
refs_to_dataframe(refs, src, record_size=10)
r = subprocess.run(["python3", "tools/kerchunk_remap.py", src, "--scan"], capture_output=True, text=True); print(r.stdout)
dst = os.path.join(td, "dst.parq")
r = subprocess.run(["python3", "tools/kerchunk_remap.py", src, dst,
                    "--rule", f"https://thredds.nci.org.au/thredds/fileServer/={gdata}/", "--check"],
                   capture_output=True, text=True)
print(r.stdout, r.stderr); assert r.returncode == 0
fs = fsspec.filesystem("reference", fo=dst, remote_protocol="file")
out = xr.open_dataset(fs.get_mapper(), engine="zarr", backend_kwargs={"consolidated": False}, zarr_format=2)
assert np.allclose(out["mld"].values, ds["mld"].values)
## unmatched rule -> nonzero exit
r = subprocess.run(["python3", "tools/kerchunk_remap.py", src, dst + "2", "--rule", "s3://x/=/y/", "--check"], capture_output=True, text=True)
print(r.stdout.strip()); assert r.returncode != 0
print("remap test pass")
