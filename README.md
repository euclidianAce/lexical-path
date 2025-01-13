# lexical-path

An attempt at an abstract Path type that allows for a common subset of
operations to be made cross platform.

This path type is “lexical” in that it is not concerned with actual existing
paths, but just the names/spelling of those paths.

# Definitions

A `path` is an array of `component`s, which are just strings. When a
`path` is represented by a string, each `component` is separated by a path
`separator` (which is usually `/` or `\`). For this library, path `separator`s
only matter when parsing or rendering a path from or to a string.

# Assumptions made by this library

(For these examples assume that `/` is the path separator.)

 - A component consisting of a single `.` has no effect on the path: `foo/./bar == foo/bar`
 - A component consisting of `..` is a traversal to the previous component: `foo/../bar == bar`
 - Trailing separators have no effect on the path: `foo/bar/ == foo/bar`
 - Paths are case sensitive: `foo/Bar ~= foo/bar`
 - Repeated separators/empty components have no effect on the path: `foo//bar == foo/bar`

# Absolute Paths and Roots

A path may be either “absolute” or “relative”. For Unix platforms, an absolute
path will start with a “/”, and Windows absolute paths will start with “\” and
maybe a drive letter like “C:\”.

Additionally, a path may be “rooted”. A root is analogous to a drive letter on
Windows or a chroot on Unix. Roots are also “lexical” in the sense that they
are only used for comparison and don't necessarily reflect any filesystem
behavior.

Both relativity and roots are only used for comparison. See documentation of
individual functions/methods to see how relativity and roots affect the results.

# Parsing

Two functions are provided to parse paths:

 - `from_unix`: uses `/` as a path separator, doesn't produce rooted paths
 - `from_windows`: uses both `/` and `\` as path separators, may produce rooted paths for drive letters, UNC paths, etc.

Additionally, a `from_os` function is provided which detects whether the unix or windows parser should be used from `package.config`
