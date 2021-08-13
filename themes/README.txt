Behold, a super-crude template system!

These files appear to be .html (etc.) files, but they're actually just snippets assembled by the main script.

Many snippets contain UUIDs swapped out at start-time or run-time by the server.

The theme is chosen by modifying ../CONFIGME.json

If a snippet is missing from the chosen theme, it will read the equivalent from ./fallback/ instead. If both the theme and fallback lack a needed snippet, the server won't start.