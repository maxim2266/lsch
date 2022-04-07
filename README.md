## DIRT (DIRectory Tracker)

Another little Linux command line utility to track changed files in a directory tree.

### Details
The tool command line format is simple:
```
$ dirt COMMAND [OPTIONS]...
```
where `COMMAND` must be one of the following:
- `init`: initialises the current directory for tracking.
- `commit`: records the state of the directory tree rooted at the current directory.
- `list`: displays all the files added, deleted, or modified since the last `commit` command was invoked.
- `help`: displays a help string.

The `dirt list` command displays changed, added, and removed files, one per line, each prefixed
by a status symbol and a space. The status symbol is '`+`' for added files,
'`-`' for deleted files, and '`*`' for modified files. Only regular files and symbolic links are tracked.

The tool is not meant to replace version control systems like `svn` or `git`,
it provides much simpler functionality, basically limited to detecting changed files.
It does not store any `diff` information, nor it maintains any history beyond the state of the
directory tree at the last `commit` command. The same time the tool is useful in scenarios where
only the names of the changed (deleted, modified) files are important, for example, when creating an
incremental backup. Personally, I use it to monitor my `Pictures` folder where I regularly
upload photographs from my camera and then edit and/or reorganise them in some way.
After some time it becomes difficult to recall which files have been added, deleted, etc., and
the tool helps me to find this out.

### Technical details
The utility operates on the current directory only.
The `dirt init` command initialises the directory for tracking by creating `.dirt.db` file.
The file contains the state of the directory, and is updated on each `dirt commit`.

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

So far the tool has been tested on Linux Mint 20.3 only, but it is likely to work on other
distributions as well.

### Installation
None as such, just run `make`, and then copy the file `dirt` over to a directory listed in
your `PATH` environment variable.
