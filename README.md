# CSPRNG D Library

* Author: [Jonathan M. Wilbur](https://jonathan.wilbur.space) <[jonathan@wilbur.space](mailto:jonathan@wilbur.space)>
* Copyright Year: 2018
* License: [MIT License](https://mit-license.org/)
* Version: [1.1.1](https://semver.org/)

## What Is This Library?

This is a library for generating cryptographically random numbers. The acronym,
CSPRNG, stands for "Cryptographically-Secure Pseudo-Random Number Generator."
This library relies upon existing system sources for cryptographic randomness.

When compiled on Windows, it uses the `BCryptGenRandom`, `CryptGenRandom`, or
`RtlGenRandom` system APIs. When compiled on Linux, FreeBSD, or DragonFlyBSD,
it reads random bytes from `/dev/random`. When compiled on Mac OS X, OpenBSD,
or NetBSD, it reads random bytes from the `arc4random_buf` function in the
C runtime library. Regardless of underlying operating system, it resorts to
the `arc4random_buf` function if the Bionic C Library is in use.

## Building and Installing

There are four scripts in `build/scripts` that help you build this library,
in addition to building using `dub`. If you are using Windows, you can build
by running `.\build\scripts\build.ps1` from PowerShell, or `.\build\scripts\build.bat`
from the traditional `cmd` shell. If you are on any POSIX-compliant(-ish)
operating system, such as Linux or Mac OS X, you may build this library using
`./build/scripts/build.sh` or `make -f ./build/scripts/posix.make`. The output
library will be in `./build/libraries`. The command-line tools will be in
`./build/executables`.

For more information on building and installing, see `documentation/install.md`.

## Library Usage

The usage of this library is really straight-forward. Whether you are on Windows,
Mac OS X, or Linux, generating cryptographically-secure random bytes looks like
this:

```d
import csprng.system;
CSPRNG c = new CSPRNG();
writeln(c.getBytes(10)); // Writes ten random bytes to the command line.
```

Alternatively, you can get random numeric data types, including static arrays
of numeric types like so:

```d
import csprng.system;
CSPRNG c = new CSPRNG();
writeln(c.get!(int[4])()); // Writes an int[4] where each int is random.
```

On the backend, this library handles opening, caching, and closing file
descriptors, and efficiently managing the Windows cryptography API constructs,
so you don't have to!

If the `CSPRNG` object fails to load the system APIs for generating secure
random bytes, it will throw a `CSPRNGException`.

## Command-Line Tool Usage

This library comes with a simple command-line tool for generating secure
random bytes, called `get-cryptobytes`. It is used like so:

```bash
get-cryptobytes 10
```

It takes only a single argument, specifying the number of random bytes wanted.

## Development

Though this library is ready for production, there are a few changes I plan to
make:

- [x] Implement a `get` templated method that retrieves a random equivalent of any parameterized numeric data type.
- [ ] Make `SecureARC4Random` implementations fall back on `/dev/random` if `SecureARC4Random` is not present.
- [ ] At least include assembly files for `RDRAND`.

## Special Thanks

Thanks to [Nathan Sashihara](https://github.com/n8sh) ([@n8sh](https://github.com/n8sh))
for adding support for the use of `arc4random_buf`, and finding a few bugs as well.

## Notes

* "ARC4" is a trademark of [RSA Laboratories](https://www.rsa.com/).

## Contact Me

If you would like to suggest fixes or improvements on this library, please just
[leave an issue on this GitHub page](https://github.com/JonathanWilbur/csprng-d/issues). If you would like to contact me for other reasons,
please email me at [jonathan@wilbur.space](mailto:jonathan@wilbur.space)
([My GPG Key](https://jonathan.wilbur.space/downloads/jonathan@wilbur.space.gpg.pub))
([My TLS Certificate](https://jonathan.wilbur.space/downloads/jonathan@wilbur.space.chain.pem)). :boar: