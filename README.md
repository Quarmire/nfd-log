# NFD LOG
A small unix socket server which serves NFD log information to clients at the socket path: `/tmp/nfdlog.sock`

The install script modifies the systemd nfd.service to pipe logs to nfd_log's STDIN and installs the binary to /usr/bin; the included nfd.conf file also replaces the exising one at /etc/ndn/nfd.conf with settings configured for ndnpipes-rs.

The `nfd_read` utility is also installed to view logs.

## Installation
Run the commands:
```
chmod +x install.sh
```
For resource-constrained systems, use:
```
./install.sh download
```
If you would like to compile from source, use:
```
./install.sh compile
```

## Uninstallation
Run the commands:
```
chmod +x uninstall.sh
```
```
./uninstall.sh
```

## View NFD Logs
Run the commands:
```
nfd_read
```