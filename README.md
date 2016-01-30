# pscp

(WIP) parallel scp

## Install

Make sure you have [cpanm](https://github.com/miyagawa/cpanminus).
If not, install it first:

```sh
$ curl -sL http://cpanmin.us | perl - -nq App::cpanminus
```

Then:

```sh
$ cpanm -nq git://github.com/shoichikaji/pscp.git
```

## Usage

```sh
# copy local 'file.txt' to 10 remote hosts (example[01-10].com) in parallel
pscp file.txt 'example[01-10].com:file.txt'

# copy remote 'file.txt' to local file.txt.${host} in parallel
pscp 'example.{com,jp}:file.txt' file.txt
```

## License

Copyright (c) 2016 Shoichi Kaji

This software is licensed under the same terms as Perl.
