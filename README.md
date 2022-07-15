## lsch: list changes made to the current directory

Another little Linux command line tool to track changes to a directory tree.

### Invocation
```
▶ lsch --help
Usage: lsch [CMD] [OPTIONS]...

List all added, deleted, and modified files in the current directory and its subdirectories.

Without CMD argument the tool shows all changes made since the last commit.
  Options:
    -0   use ASCII null as output separator

The CMD argument, if given, must be one of the following:
  init            initialise the current directory for tracking changes
                  Options:
                    -f,--force   remove any previous tracking data
  commit          commit all changes
  help,-h,--help  display this help and exit
```

The modified files are displayed one per line, each prefixed with a status symbol and a space.
The status symbol is '`+`' for added files, '`-`' for deleted files, and '`*`' for modified files.
Only regular files and symbolic links are tracked.

The tool is not meant to replace version control systems like `svn` or `git`,
it provides much simpler functionality, basically limited to detecting changed files only.
It does not store any `diff` information, nor it maintains any history beyond the state of the
directory tree at the last `commit`. The same time the tool is useful in scenarios where
only the names of the changed (deleted, modified) files are important, for example, when creating an
incremental backup.

### Technical details
The tool operates on the current directory only. The `lsch init` command initialises the directory
for tracking by creating `.lsch.db` file. The file contains the state of the directory, and is updated 
on each `lsch commit`.

Internally, the tool relies on `sha256sum` utility for calculating checksums of files. Those checksums
are used for change detection.

Symbolic links are not followed, only their target pathnames get compared.

Just to clarify, this tool does not use `inotify`.

### System requirements
Lua version 5.3, plus the following (well-known) Linux utilities:
* `sha256sum`
* `find`
* `gzip`
* `readlink`
* `xargs`

So far the tool has been tested on Linux Mint 20.3 only, but it is likely to work on other
distributions as well.

### Installation
None as such, just run `make`, and then copy the file `lsch` over to a directory listed in
your `PATH` environment variable.
