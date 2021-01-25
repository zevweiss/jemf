#!/usr/bin/python3
#
# Format version history:
#
# - v0: top-level map with data & metadata keys
#   - metadata: timestamp, timezone, and hostname of last modification
#   - data: files are strings, directories are maps
#
# - v1: files and directories may optionally instead be length-2 arrays:
#   - a data string or directory-entry map
#   - a metadata map:
#     - mhost: hostname of last modification
#     - mtime: (float) unix timestamp of last modification
#     - mtzname: timezone of last modification
#
# - v2:
#   - per-file/directory metadata mandatory instead of optional
#   - explicit format_version record in top-level metadata (integer)
#
# - v3: unified representation:
#   - all files and directories are now maps with common metadata:
#     - mhost, mtime, and mtzname as in v2
#     - type:
#       - 'd' for directories
#       - 'f' for files
#       - 'l' for symlinks (new)
#   - each type has one additional key for its contents:
#     - directories: "entries" (map)
#     - files: "data" (string)
#     - symlinks: "target" (string)

import sys
import json
import argparse

import jemf

def ensure_v2(fs):
	if fs["metadata"].get("format_version", 0) >= 2:
		return (fs, False)

	def add_metadata(item):
		if not isinstance(item, list):
			item = [item, dict(mhost="(unknown)", mtime=0.0, mtzname="GMT")]

		assert(len(item) == 2)
		assert(isinstance(item[1], dict))
		assert(sorted(item[1].keys()) == ["mhost", "mtime", "mtzname"])

		if isinstance(item[0], dict):
			item[0] = { k: add_metadata(v) for k, v in item[0].items() }

		return item

	fs["data"] = add_metadata(fs["data"])
	fs["metadata"]["format_version"] = 2

	return (fs, True)

def v2_to_v3(fs):
	if fs["metadata"].get("format_version", 0) >= 3:
		return (fs, False)

	def convert_objects(item):
		assert(isinstance(item, list))
		assert(len(item) == 2)

		content, metadata = item

		assert(isinstance(metadata, dict))
		assert(sorted(metadata.keys()) == ["mhost", "mtime", "mtzname"])

		newobj = metadata
		if isinstance(content, str):
			newobj["type"] = 'f'
			newobj["data"] = content
		elif isinstance(content, dict):
			newobj["type"] = 'd'
			newobj["entries"] = { k: convert_objects(v) for k, v in content.items() }
		else:
			raise ValueError("unexpected content type %s" % type(content))

		return newobj

	fs["data"] = convert_objects(fs["data"])
	fs["metadata"]["format_version"] = 3

	return (fs, True)

version_funcs = [
	None,
	None, # v1 is fully backwards-compatible with v0
	ensure_v2,
	v2_to_v3,
]

assert jemf.CURRENT_FORMAT_VERSION == len(version_funcs) - 1

def main():
	parser = argparse.ArgumentParser(description="update jemf fs file format version")
	parser.add_argument("-V", "--to-version", type=int, metavar="VERSION",
			    help="format version to update to", default=jemf.CURRENT_FORMAT_VERSION)
	parser.add_argument("fsfile", type=str, help="FS file to operate on")

	args = parser.parse_args()

	if args.to_version < 2 or args.to_version > jemf.CURRENT_FORMAT_VERSION:
		print("Invalid version %d" % args.to_version, file=sys.stderr)
		exit(1)

	passwd = jemf.getpass("Enter password for %s: " % args.fsfile)

	# this sets up an automatic unlock via atexit, so we don't
	# need to do it manually here
	jemf.lock_fsfile(args.fsfile)

	fs = json.loads(jemf.gpg_decrypt(args.fsfile, passwd))

	for v in range(args.to_version + 1):
		fn = version_funcs[v]
		if fn is None:
			continue
		fs, updated = fn(fs)
		msg = "Updated to" if updated else "No update necessary for"
		print("%s version %d..." % (msg, v))

	newplaintext = jemf.pretty_json_dump(fs).encode("utf-8") + b'\n'
	jemf.update_fsfile(args.fsfile, passwd, newplaintext)

	print("%s is now in format version %d." % (args.fsfile, args.to_version))

if __name__ == "__main__":
	main()
