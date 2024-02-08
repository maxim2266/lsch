## lsch: list all added, deleted, and modified files in the current directory and its subdirectories.

Another little command line tool for Linux to track modifications within a directory tree.

### Invocation
```
▶ lsch --help
Usage: lsch [CMD] [OPTIONS]...

List all added, deleted, and modified files in the current directory and its subdirectories.

Without CMD argument the tool shows all changes made since the last reset.
  Options:
    -0   use ASCII null as output separator

The CMD argument, if given, must be one of the following:
  init            create empty change tracking database in the current directory
                  Options:
                    -f,--force   discard any previous tracking data
  reset           accept current state as the reference for further change tracking
  help,-h,--help  display this help and exit
```

Modified items are displayed one per line, each prefixed with a status symbol and a space.
The status symbol is '`+`' for added files, '`-`' for deleted files, and '`*`' for modified files.
Only regular files and symbolic links are tracked. The current directory and all its sub-directories
must not be modified while the scan is in progress.

The tool is not meant to replace version control systems like `svn` or `git`, instead
it provides much simpler functionality, basically limited to detecting changed files only.
It does not store any `diff` information, nor it maintains any history beyond the state of the
directory tree at the last `reset`. The same time the tool is useful in scenarios where
only the names of the changed (deleted, modified) files are important, for example, when creating an
incremental backup.

### Technical details
The tool operates on the current directory only. The `lsch init` command initialises the directory
for tracking by creating `.lsch.db` file. The file contains the state of the directory and its
sub-directories, and is updated on each `lsch reset`.

Internally, the tool relies on `sha256sum` utility for calculating checksums of files. Those checksums
are used for change detection.

Symbolic links are not followed, only their target pathnames get compared.

### System requirements
Lua version 5.3, plus the following (well-known) Linux utilities:
* `sha256sum`
* `find`
* `gzip`
* `readlink`
* `xargs`

So far the tool has been tested on Linux Mint from version 20.3 and above, but it is likely to work
on other (at least Debian-based) Linux distributions.

### Installation
None as such, just run `make`, and then copy the file `lsch` over to a directory listed in
your `PATH` environment variable.
