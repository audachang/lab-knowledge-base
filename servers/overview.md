# Lab Server Overview

| Alias | IP | User | Port | OS | Provider | Notes |
|---|---|---|---|---|---|---|
| braina-aclexp | 89.167.10.76 | aclexp | 22 | Ubuntu 24.04 | Hetzner | NVIDIA RTX 2070 SUPER; NoMachine installed |
| braina-openclaw | 89.167.10.76 | openclaw | 22 | Ubuntu 24.04 | Hetzner | Same physical machine as braina-aclexp |
| braino-audachang | 34.80.2.227 | audachang | 22 | Debian 12 | GCP | |
| aws_server | 35.72.190.78 | ubuntu | 22 | Ubuntu 20.04 | AWS | Lacks post-quantum key exchange; OpenSSH upgrade recommended |
| node23 | 140.115.47.23 | aclexp | 22 | Ubuntu 24.04 | NCU | |
| node34 | 140.115.47.34 | aclexp | 22 | Ubuntu 24.04 | NCU | |
| node37 | 140.115.47.37 | aclexp | 2222 | Ubuntu 24.04 | NCU | Non-standard port |

All servers verified accessible as of 2026-02-23.

## Software Stack (braina-aclexp)

- FSL + FSLeyes 0.31.2 (FSL Python 3.7 conda env at `/usr/local/fsl/`)
- FreeSurfer
- MATLAB R2021b
- NoMachine 9.2.18
- NVIDIA driver 580.126.09, CUDA 13.0
- Micromamba at `/usr/local/micromamba/`
- Anaconda3 at `/home/aclexp/anaconda3/`
