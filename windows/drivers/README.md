# Vendored Drivers

These files are committed to the repo so `setup.ps1` never downloads a kernel
driver from a third-party server at install time.

| File | Source | License | SHA256 |
|------|--------|---------|--------|
| `EC-Access-Tool.exe` | [shubhampaul/EC-Access-Tool](https://github.com/shubhampaul/EC-Access-Tool) (v1.0.0-beta, release asset) | GPLv3 | `504a58b1faba08b25a45d51de5996bf7cb31f461e28f1a270d2e53b1f3fda8ac` |
| `WinRing0x64.sys` | [OpenLibSys](https://openlibsys.org/) (via CrystalDiskMark) | BSD-3-Clause | `11bd2c9f9e2397c9a16e0990e4ed2cf0679498fe0fd418a3dfdac60b5c160ee5` |

## RwDrv.sys

RwDrv is **not** bundled. It ships with [RW-Everything](http://rweverything.com/)
(a free download) and copying it here would be redistributing a proprietary
driver without permission. If you want to use RwDrv:

1. Install RW-Everything
2. Copy `C:\Windows\System32\drivers\RwDrv.sys` into this folder
3. Run `setup.ps1` — it will detect the local copy and prefer it

## Verification

```powershell
Get-FileHash .\EC-Access-Tool.exe, .\WinRing0x64.sys -Algorithm SHA256
```

Hashes above are pinned in `setup.ps1`; setup refuses to install on mismatch.
