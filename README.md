# nix-cluster

A nix configuration of a *tiny* SLURM-based HPC cluster.


Originally, this was a draft for a HPC cluster shared between a
few researchers.
Due to some decisions, it was never used, so I stripped identifying
information to release it publicly as an inspiration source.

I'll likely continue to work on it as a testing playground.

## Structure

Note that the intended hardware is only provided for reference, as it
influences the SLURM configuration

 - `server01`, `server02`
   - Intended for CPU-heavy computations
 - `server03`
   - Intended for CUDA computations
 - `server04`
   - Lower-End Administration Node
	 - Authentication source
	 - Slurm Controller
	 - SSH Entrypoint
	 - Physical location for `~`

All servers are reachable via an external interface/address, while
having a shared (static) network on a separate, internal interface.

## Features

 - [X] Deployment with [`nixinate`](https://github.com/MatthewCroughan/nixinate)
 - [X] Secret Management with [`sops`](https://github.com/getsops/sops) and [`sops-nix`](https://github.com/Mic92/sops-nix)
 - [X] Automated testing
 - [ ] Cluster-wide user management with `kanidm`
   - [ ] Testing
 - [X] SLURM for Workload Management
   - [X] `munged`
     - [X] Testing mutual authentication
   - Controller
	 - [X] `slurmdb`
	 - [X] `slurmctld`
	 - [X] `mariadb`
   - Nodes
	 - [X] `slurmd`
   - [ ] Syncing of SLURM accounts with unix groups
   - [X] Testing the execution of simple commands
 - [X] Shared file system
   - [X] NFS
	 - [X] Testing mutual visibility of files
   - [ ] ~~Ceph~~ (Maybe experiment with it)
 - [X] Testing the assumed network setup
 - [ ] Monitoring and Alerting
   - [ ] Grafana
   - [ ] Prometheus
	 - [ ] Node Exporter
	 - [ ] SLURM Exporter


