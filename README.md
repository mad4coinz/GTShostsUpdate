# GTShostsUpdate

A small shell script that downloads ad and tracker blocklists, merges them and installs the result as
your hosts file, so those hosts resolve to `0.0.0.0` on every app and browser. macOS and Linux.

## Use

```sh
./update-hosts.sh -o hosts.preview     # dry run: build into a file and look at it first
sudo ./update-hosts.sh                 # build and install as /etc/hosts, then flush the DNS cache
sudo ./update-hosts.sh --restore       # undo: put back the hosts file from before the first install
```

The first install saves your original hosts file as `/etc/hosts.before-GTShostsUpdate`.
If a download fails, or the lists come back nearly empty, nothing is changed.

## Settings

Optional files next to the script (copy the `.example` versions; they are kept out of git):

- `sources`: blocklist URLs in hosts format. The default is
  [StevenBlack's unified hosts](https://github.com/StevenBlack/hosts), which already combines AdAway,
  MVPS, Peter Lowe's list, Dan Pollock's list, URLhaus and others.
- `whitelist`: hosts never to block, exact names (whitelisting `example.com` does not unblock
  `ads.example.com`).
- `myhosts`: your own entries, put at the top. Without it the standard `localhost` lines are used.

## Keeping it up to date

The lists change often. To refresh weekly, add a root cron job (`sudo crontab -e`):

```
0 9 * * 1 /path/to/GTShostsUpdate/update-hosts.sh
```
