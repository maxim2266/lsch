## DIRT (DIRectory Tracker)

A tiny Linux command line utility to monitor and display changes made to a directory tree
since some point in the past.

###### Licence: BSD 3-clause


### Details
The tool command line format is simple:
```
$ dirt COMMAND
```
where `COMMAND` must be one of the following:
- `init`: initialises the current directory for tracking.
- `accept`: records the state of the directory tree rooted at the current directory.
- `show`: displays all the files added, deleted or modified since the last `accept` command was invoked.
- `reset`: discards tracking information, leaving it as it was right after the `init` command.

The `dirt show` command displays the file pathnames one per line, starting from a status
symbol, followed by one space, followed by the file path.
The status symbol is '`+`' for added files, '`-`' for deleted files and '`*`' for modified files.

The tool is not meant to replace version control systems like `svn` or `git`,
it provides much simpler functionality, basically limited to detecting changed files.
It does not store any `diff` information, nor it maintains
any history beyond the state of the directory tree at the last `accept` command.
The same time the tool is useful in scenarios where only the names of the
changed (deleted, modified) files are important, for example, when creating an
incremental archive. Personally, I use it to monitor my `Photo` folder where I regularly
upload photographs from my camera and then I edit and/or reorganise them in some way.
After some time it becomes difficult to recall which photographs have already been
edited, what files have been added, deleted, etc., and this tool helps me to find
this out quickly.

The utility also has the capability to filter out unwanted files to exclude them
from tracking (see below for details).

### Technical details
The utility operates on the current directory only.
The tool initialises the directory for tracking by creating `.dirt` subdirectory in it.
In this subdirectory the tool maintains the file called `state`, where it stores the
tracking information. The information gets overwritten each time `dirt accept` command
is invoked; initially the file does not exist. In Python terms,
the file is a pickled dictionary object, mapping file pathnames to their corresponding
md5 checksums. `dirt reset` command simply deletes the tracking file.

Internally, the tool relies on `md5sum` Linux utility for processing larger files
in parallel with the main program.

Optionally, the `.dirt` directory may contain the file called `excluded`, where
user can store a list of globs (see `glob(7)`) of the file/directory names he or she does not
want to be tracked. The globs should be stored one per line, with empty lines ignored.
For example, to exclude all `git` related subdirectories one can simply do
```bash
$ echo .git > .dirt/excluded
```
