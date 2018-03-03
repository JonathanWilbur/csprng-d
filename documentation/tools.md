# CSPRNG Library Tools

This library comes with a simple command-line tool for generating secure
random bytes, called `get-cryptobytes`. It is used like so:

```bash
get-cryptobytes 10
```

It takes only a single argument, specifying the number of random bytes wanted.

Exit Code | Meaning
----------|-------------------------------------------------------------------------------
0         | Success
1         | Invalid number of arguments
2         | Exception encountered when trying to load system APIs for getting random bytes
3         | Exception encountered when trying to load the selected function from the system API or when trying to read from /dev/random.
4         | Number of bytes to generate is too large.
5         | Second argument is not a number.