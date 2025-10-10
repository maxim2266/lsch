## lsch: list all added, deleted, or modified files in the current directory and its subdirectories.

Another little Linux tool for tracking modifications within a directory tree.

### Invocation
```
▶ ./lsch --help
Usage: lsch [OPTIONS]

List all added, deleted, or modified files in the current directory and its subdirectories.

Options:
  -0          use ASCII null as output separator
  -r,--reset  record the current state of the directory tree for further comparisons
  -h,--help   display this help and exit
```

Modified items are displayed one per line, each prefixed with a status symbol and a space.
The status symbol is '`+`' for added files, '`-`' for deleted files, and '`*`' for modified
files.  Only regular files and symbolic links are tracked. The current directory and all its
subdirectories must not be modified while the scan is in progress.

The tool does not store any `diff` information (like `svn` or `git`), nor it maintains any
history beyond the state of the directory tree at the last `lsch -r` invocation. Typically
the tool is useful in scenarios where only the names of the changed (deleted, modified) files
are important, for example, when creating an incremental backup.

### Technical details
The tool operates on the current directory only. The `lsch -r` starts tracking the directory by
creating `.lsch.db` database file, and each subsequent `lsch -r` updates the file, while `lsch`
(with no parameters) uses the database to display the changes.

Symbolic links are not followed, only their target pathnames get compared.

### System requirements
Lua version 5.4, plus the following Linux utilities:
* `sha256sum`
* `find`
* `gzip`
* `xargs`

So far the tool has been tested on Linux Mint from version 20.3 and above, but it is likely to work
on other (at least Debian-based) Linux distributions.

### Installation
Clone the repository with `git clone --recursive`, then either
* `make install` to install `lsch` system-wide, or
* `make PREFIX=~ install` for local installation, or
* just `make` and then copy `lsch` file to any suitable location.
