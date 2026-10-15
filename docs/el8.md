# el8 releases: container, not a VM

Some releases in use, such as `CMSSW_20_0_0_patch1` (D128 RelVal inputs, NGT studies), have an `el8_aarch64_gcc13` build but no `el9_aarch64` one. A second, AlmaLinux 8 Lima VM was proposed so they could run natively with the usual shell setup. It was dropped on 2026-10-15.

## Why not an el8 VM

AlmaLinux 8.10 aarch64 (Lima's `template://almalinux-8`, kernel 4.18) does not boot on Apple Silicon:

- with `vmType: vz` the guest spins at 100% CPU with no console output;
- with `vmType: qemu` the console shows `EFI stub: ERROR: This 64 KB granular kernel is not supported by your CPU`.

The el8 aarch64 kernel is built for 64 KB pages, and Apple Silicon only supports 4 KB and 16 KB pages, so this applies to every M-series chip (Lima's template only warns about M1, lima-vm/lima#841). The el9 kernel uses 4 KB pages. Rosetta with `el9_amd64` was ruled out: CMSSW needs x86_64 system libraries that an aarch64 guest cannot install, and emulated timings are useless for benchmarks.

## What is used instead

The CMS el8 container on CVMFS (`/cvmfs/cms.cern.ch/common/cmssw-el8`, image `/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el8:aarch64`) runs the el8 user space on the el9 kernel, which is all CMSSW needs:

- apptainer from `/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin` runs it unprivileged, at native speed;
- `/home`, `/cvmfs` and `/data` are bound automatically;
- it starts in about 0.1 s once CVMFS has cached the image (0.7 s with `cmsenv`);
- the image has zsh 5.5, git and the el8 OpenSSL 1.1 that `git cms-init` needs.

`cmssw-el8` (`guest/bin/cmssw-el8`) adds apptainer to `PATH`, the el8 `SCRAM_ARCH`, the zsh plugins and the `~/.local/bin` tools, and starts zsh. `cmssw-bootstrap` runs el8 architectures through it.

Delete `docs/el8.md` and the el8 parts of `cmssw-bootstrap` once the releases in use have el9_aarch64 builds.
