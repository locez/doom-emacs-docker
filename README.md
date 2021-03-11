# doom-emacs-docker

doom emacs in docker

# Usage

make sure your current user can run docker command, if it does not take effect, simply try to reboot your system

```bash
# sudo usermod -a -G docker locez
```

generate `Dockerfile`, `docker-compose.yml` and `doom-emacs` script

```bash
$ ./generate.sh
```

start doom emacs docker

```bash
$ docker-compose up -d
```

sync your config

```bash
$ doom-emacs sync
```
just start emacs

```
$ doom-emacs
```
maybe you want enter docker's shell

```bash
$ doom-emacs shell
```




