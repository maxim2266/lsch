Things to add in the future:
- Deduplication on `inode` to avoid unnecessary checksum calculations;
- Restore filter settings, like in v1. Can be done as a list of parameters for `find ! -path`
  or `find ! -name`, in the form of a config file in Lua.