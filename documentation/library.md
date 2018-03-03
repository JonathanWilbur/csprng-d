## Library Usage

The usage of this library is really straight-forward. Whether you are on Windows,
Mac OS X, or Linux, generating cryptographically-secure random bytes looks like
this:

```d
import csprng.system;
CSPRNG c = new CSPRNG();
writeln(c.getBytes(10)); // Writes ten random bytes to the command line.
```

On the backend, this library handles opening, caching, and closing file
descriptors, and efficiently managing the Windows cryptography API constructs,
so you don't have to!

If the `CSPRNG` object fails to load the system APIs for generating secure
random bytes, it will throw a `CSPRNGException`.