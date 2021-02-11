# jemf
--------

An encrypted mini-filesystem, useful as a command-line password manager.

Whence the 'j'?  Take your pick of:

  - jeneric (?)
  - JSON
  - Scout's older brother

### Requirements

  - Python 2.7/3.2+
  - gpg

### Installation

Put the `jemf` executable wherever you like (presumably somewhere in your
`$PATH`).  If for some reason your python interpreter isn't at
`/usr/bin/python`, you may want to edit the shebang line accordingly

### Usage

jemf acts like a miniature filesystem of sorts, albeit not with quite the
full generality of a real filesystem -- the biggest limitation being that
files may each contain only a single line of text.

jemf operates via subcommands.  `jemf mkfs` initializes an empty
filesystem, after which you can use further subcommands to create
directories (`jemf mkdir`) and files (`jemf create`) within it.  The
contents of a file can be written to stdout with `jemf cat`; this can then
of course be piped into a clipboard manager (e.g. `xsel`/`xclip` on X11,
`pbcopy` on Mac OS X) for convenient pasting.

By default, so as to reduce the risk of accidental disclosure, jemf will
refuse to print file contents to your terminal (though if you *really* want
to you can force it to do so via `jemf cat -f`).

See `jemf --help` for a summary of available subcommands and `jemf COMMAND
--help` for details on the usage of subcommand `COMMAND`.

##### Shell mode

If you're going to be performing multiple jemf operations (for example an
`ls` if you don't remember quite exactly what name you stored something
under, followed by a `cat` once you've found it) and don't want to enter
your passphrase for each one, jemf has a `shell` subcommand that prompts
for the master passphrase once and then presents an interactive command
prompt (including readline-enabled tab-completion).

The `-p` flag can be used to provide a shell command (the "real" system
shell, not jemf's shell) to which file contents are sent instead of stdout
(something like `xsel`, `xclip`, or `pbcopy` would again probably be a
useful choice here).

##### Data generation

`jemf create` and `jemf edit` feature a flag (`-g`) that allows automatic
generation of semi-random data according to user-provided constraints
intended to match the kind of password rules commonly imposed by various
sites (e.g. "must contain at least one capital letter, one lower-case
letter, and one digit").  See their `--help` text for how exactly to
specify the constraints.

### Data storage

jemf stores data in a single JSON file symmetrically encrypted under a
master passphrase via gpg.  Each jemf filesystem object (file,
directory, or symlink) is stored as a JSON object, each of which has a
set of common metadata fields that indicate what type of object it is
(`type`) and record the timestamp, time zone, and hostname of its last
modification (`mtime`, `mtzname`, and `mhost`, respectively).  Each
type has one additional type-specific field: `entries` for directories
(an object mapping names to other filesystem objects), `data` for
files (a string of its contents), and `target` for symlinks (the path
the symlink points to).  The top-level structure of the JSON file is
an object with two elements, `data` and `metadata`.  `data` is the
root directory of the (mini-)filesystem; `metadata` stores a format
revision number (currently 3) as well as the timestamp, timezone, and
hostname of the last modification made to the filesystem as a whole.

### Format versions

The exact format of the JSON file in which jemf stores its data has
evolved somewhat over time; it will complain if the format revision of
the file does not match that of the program itself.  The
`update-jemf.py` script can be used to update an existing file from an
older format revision to a newer one (run `./update-jemf.py --help`
for usage information).  Note that it updates the file in place; you
are strongly encouraged to make a backup of your existing file in case
anything goes awry with the update procedure.

### License

jemf is licensed under the terms of the ISC License (see `LICENSE`).
