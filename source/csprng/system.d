/**
    A Cryptographically-Secure Pseudo-Random Number Generator that uses system
    APIs as its source of secure random bytes. In the case of Windows, it uses
    the $(MONO BCryptGenRandom), $(MONO CryptGenRandom), and $(MONO RtlGenRandom)
    libraries in that order of fallback. On POSIX-ish systems, it uses the
    pseudo-device, $(MONO /dev/random), as its source of secure random bytes.

    Authors:
    $(UL
        $(LI $(PERSON Jonathan M. Wilbur, jonathan@wilbur.space, http://jonathan.wilbur.space))
    )
    Copyright: Copyright (C) Jonathan M. Wilbur
    License: $(LINK https://mit-license.org/, MIT License)
*/
module csprng.system;
private import std.conv : text;

version (CRuntime_Bionic)
{
    version = SecureARC4Random;
}
else version (OSX)
{
    version = SecureARC4Random;
}
else version (OpenBSD)
{
    version = SecureARC4Random;
}
else version (NetBSD)
{
    version = SecureARC4Random;
}

version (SecureARC4Random)
{
    private extern (C) void arc4random_buf(scope void* buf, size_t nbytes) @nogc nothrow @system;
}

///
public alias CSPRNGException = CryptographicallySecurePseudoRandomNumberGeneratorException;
/// A generic CSPRNG exception
public
class CryptographicallySecurePseudoRandomNumberGeneratorException : Exception
{
    import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

///
public alias CSPRNG = CryptographicallySecurePseudoRandomNumberGenerator;
/**
    The class that wraps the system's CSPRNG APIs, making it easy to
    retrieve cryptographically-secure pseudo-random bytes.
*/
public
class CryptographicallySecurePseudoRandomNumberGenerator
{
    version (Windows)
    {
        import core.sys.windows.windows;

        /* NOTE:
            Question: Should I call malloc() before using these pointers to store data?
            Answer: I don't believe so, because the memory _should be_ allocated by the
                loader already. All of the pointers are pointers to functions within the
                loaded library, so that should not cause a problem, either.
        */
        private alias BCRYPT_ALG_HANDLE = void*;
        private alias HCRYPTPROV = void*;
        private alias NTSTATUS = uint;

        // Used by the Cryptography: Next Generation (CNG) API
        private HMODULE bcrypt; // A pointer to the loaded Bcrypt library (Bcrypt.dll)
        private BCRYPT_ALG_HANDLE cngProviderHandle; // A pointer to the CNG Provider Handle, which is used by BCryptGenRandomAddress()
        private FARPROC bCryptOpenAlgorithmProviderAddress; // A pointer to the BCryptOpenAlgorithmProvider() function, as obtained from this.bcrypt
        private FARPROC bCryptCloseAlgorithmProviderAddress; // A pointer to the BCryptCloseAlgorithmProvider() function, as obtained from this.bcrypt
        private FARPROC bCryptGenRandomAddress; // A pointer to the BCryptGenRandom() function, as obtained from this.bcrypt

        // Used by the CryptoAPI and the legacy cryptography API
        private HMODULE advapi32; // A pointer to the loaded Windows Advanced API (advapi32.dll)
        private HCRYPTPROV cryptographicServiceProviderHandle; // A pointer to the CSP, which is obtained with CryptoAcquireContext(), and used by CryptGenRandom()
        private FARPROC cryptAcquireContextAddress; // A pointer to CryptAcquireContext(), as obtained from this.advapi32
        private FARPROC cryptReleaseContextAddress; // A pointer to CryptReleaseContext(), as obtained from this.advapi32
        private FARPROC cryptGenRandomAddress; // A pointer to CryptGenRandom(), as obtained from this.advapi32
        private FARPROC rtlGenRandomAddress; // A pointer to RtlGenRandom(), as obtained from this.advapi32

        ///
        public alias isUsingCNGAPI = isUsingCryptographyNextGenerationApplicationProgrammingInterface;
        ///
        public alias isUsingCryptographyNextGenerationAPI = isUsingCryptographyNextGenerationApplicationProgrammingInterface;
        ///
        public alias isUsingCNGApplicationProgrammingInterface = isUsingCryptographyNextGenerationApplicationProgrammingInterface;
        /**
            Returns boolean indicating whether this library is using the Windows
            $(B Cryptography: Next Generation) API to generate random bytes from
            the $(MONO BCryptGenRandom) API function.

            More specifically, this library returns true if $(MONO Bcrypt.dll) was found,
            loaded, and all three requisite functions could be loaded from it,
            which are:
            $(UL
                $(LI $(MONO BCryptOpenAlgorithmProvider))
                $(LI $(MONO BCryptCloseAlgorithmProvider))
                $(LI $(MONO BCryptGenRandom))
            )
        */
        public @property @safe @nogc nothrow
        bool isUsingCryptographyNextGenerationApplicationProgrammingInterface()
        {
            return
            (
                this.bcrypt != NULL &&
                this.cngProviderHandle != NULL &&
                this.bCryptOpenAlgorithmProviderAddress != NULL &&
                this.bCryptCloseAlgorithmProviderAddress != NULL &&
                this.bCryptGenRandomAddress != NULL
            );
        }

        ///
        public alias isUsingCryptoAPI = isUsingCryptoApplicationProgrammingInterface;
        /**
            Returns boolean indicating whether this library is using the Windows
            $(B Crypto API) to generate random bytes from
            the $(MONO CryptGenRandom) API function.

            More specifically, this library returns true if $(MONO advapi32.dll) was found,
            loaded, and all three requisite functions could be loaded from it,
            which are:
            $(UL
                $(LI $(MONO CryptAcquireContext))
                $(LI $(MONO CryptReleaseContext))
                $(LI $(MONO CryptGenRandom))
            )
        */
        public @property @safe @nogc nothrow
        bool isUsingCryptoApplicationProgrammingInterface()
        {
            return
            (
                this.advapi32 != NULL &&
                this.cryptographicServiceProviderHandle != NULL &&
                this.cryptAcquireContextAddress != NULL &&
                this.cryptReleaseContextAddress != NULL &&
                this.cryptGenRandomAddress != NULL
            );
        }

        /**
            Returns a boolean indicating whether this library was able to load
            $(MONO advapi32.dll) and $(MONO RtlGenRandom) from it, and will
            use $(MONO RtlGenRandom) to obtain secure random bytes.
        */
        public @property @safe @nogc nothrow
        bool isUsingRtlGenRandom()
        {
            return
            (
                this.advapi32 != NULL &&
                this.rtlGenRandomAddress != NULL
            );
        }

        /**
            Returns the specified number of cryptographically-secure
            pseudo-random bytes, using one of the system APIs.

            Throws:
            $(UL
                $(LI $(D CSPRNGException) if one of the functions from the
                    automatically-select cryptography API could not be loaded.)
            )
        */
        public @system
        void[] getBytes (in size_t length)
        {
            if (this.isUsingCNGAPI)
            {
                ubyte[] bytes;
                bytes.length = length;
                extern (Windows) NTSTATUS function (BCRYPT_ALG_HANDLE hAlgorithm, PUCHAR pbBuffer, ULONG cbBuffer, ULONG dwFlags) BCryptGenRandom =
                    cast(NTSTATUS function (BCRYPT_ALG_HANDLE hAlgorithm, PUCHAR pbBuffer, ULONG cbBuffer, ULONG dwFlags)) this.bCryptGenRandomAddress;

                if (BCryptGenRandom(this.cngProviderHandle, bytes.ptr, bytes.length, 0u))
                    return bytes;
            }

            if (this.isUsingCryptoAPI)
            {
                ubyte[] bytes;
                bytes.length = length;
                extern (Windows) BOOL function(HCRYPTPROV hProv, DWORD dwLen, BYTE *pbBuffer) CryptGenRandom
                    = cast(BOOL function(HCRYPTPROV hProv, DWORD dwLen, BYTE *pbBuffer)) this.cryptGenRandomAddress;

                if (CryptGenRandom(this.cryptographicServiceProviderHandle, bytes.length, bytes.ptr))
                    return cast(void[]) bytes;
            }

            if (this.isUsingRtlGenRandom)
            {
                void[] bytes;
                bytes.length = length;
                extern (Windows) BOOLEAN function(PVOID RandomBuffer, ULONG RandomBufferLength) RtlGenRandom
                    = cast(BOOLEAN function(PVOID RandomBuffer, ULONG RandomBufferLength)) rtlGenRandomAddress;

                version (unittest) assert(bytes.length == length);
                if (RtlGenRandom(bytes.ptr, length))
                    return bytes;
            }

            throw new CSPRNGException
            (
                "This exception was thrown because you attempted to generate " ~
                "cryptographically secure random bytes from the csprng library, " ~
                "but none of the Windows cryptography APIs could be loaded. " ~
                "Ensure that either Bcrypt.dll or advapi32.dll is either in " ~
                "the executable's directory, current directory, the Windows " ~
                "directory, the System directory, or in one of the directories " ~
                "in the PATH environment variable. If you believe you have " ~
                "received this error by mistake, please report this as a bug " ~
                "to https://github.com/JonathanWilbur/csprng-d/issues."
            );
        }

        /**
            The constructor for a CSPRNG. When a $(D CSPRNG) is created with
            this constructor, the relevant libraries and functions from them are
            loaded. If they cannot be loaded, the constructor throws a
            $(D CSPRNGException) and the $(D CSPRNG) will not be created.

            This constructor first attempts to load the Windows
            Cryptography: Next Generation API. If that cannot be loaded, it
            attempts to load the CryptoAPI. If that cannot be loaded, it attempts
            to load the $(MONO RtlGenRandom) function. If all of those fail,
            the $(D CSPRNGException) is thrown, since no source of
            cryptographically-secure pseudo-random bytes can be accessed.
        */
        public @system
        this ()
        {
            firstTryToUseTheNextGenCryptoAPI:
                this.bcrypt = LoadLibrary("Bcrypt.dll");
                if (this.bcrypt == NULL)
                    goto fallBackOnAdvapi32;

                this.bCryptOpenAlgorithmProviderAddress = GetProcAddress(this.bcrypt, "BCryptOpenAlgorithmProvider");
                if (this.bCryptOpenAlgorithmProviderAddress == NULL)
                    goto fallBackOnAdvapi32;

                this.bCryptCloseAlgorithmProviderAddress = GetProcAddress(this.bcrypt, "BCryptCloseAlgorithmProvider");
                if (this.bCryptCloseAlgorithmProviderAddress == NULL)
                    goto fallBackOnAdvapi32;

                this.bCryptGenRandomAddress = GetProcAddress(this.bcrypt, "BCryptGenRandom");
                if (this.bCryptGenRandomAddress == NULL)
                    goto fallBackOnAdvapi32;

                {
                    extern (Windows) NTSTATUS function(BCRYPT_ALG_HANDLE phAlgorithm, LPCWSTR pszAlgId, typeof(null) pszImplementation, DWORD dwFlags) BCryptOpenAlgorithmProvider =
                        cast(NTSTATUS function(BCRYPT_ALG_HANDLE phAlgorithm, LPCWSTR pszAlgId, typeof(null) pszImplementation, DWORD dwFlags)) this.bCryptOpenAlgorithmProviderAddress;

                    if (!BCryptOpenAlgorithmProvider(&(this.cngProviderHandle), "RNG", NULL, 0u))
                        goto fallBackOnAdvapi32;
                }

                if (this.cngProviderHandle != NULL)
                    goto fallBackOnAdvapi32;
                return; // If we have a viable CSPRNG function, then we're done.

            // Since the Next-Gen Crypto API failed to load, fall back on either CryptGenRandom or RtlGenRandom from advapi32.dll
            fallBackOnAdvapi32:
                this.advapi32 = LoadLibrary("advapi32.dll");
                if (this.advapi32 == NULL)
                    throw new CSPRNGException
                    (
                        "This exception was thrown because you attempted to generate " ~
                        "cryptographically secure random bytes from the csprng library, " ~
                        "but none of the Windows cryptography libraries could be loaded. " ~
                        "Ensure that either Bcrypt.dll or advapi32.dll is either in " ~
                        "the executable's directory, current directory, the Windows " ~
                        "directory, the System directory, or in one of the directories " ~
                        "in the PATH environment variable. If you believe you have " ~
                        "received this error by mistake, please report this as a bug " ~
                        "to https://github.com/JonathanWilbur/csprng-d/issues. The " ~
                        "Windows error code associated with this particular failure is " ~
                        text(GetLastError()) ~ "."
                    );

            // This label is never used, but I want it here for visual consistency, anyway.
            fallBackOnCryptGenRandom:

                // For some reason, CryptAcquireContextW and CryptAcquireContextA existed, but not CryptAcquireContext
                this.cryptAcquireContextAddress = GetProcAddress(this.advapi32, "CryptAcquireContextW");
                if (this.cryptAcquireContextAddress == NULL)
                    this.cryptAcquireContextAddress = GetProcAddress(this.advapi32, "CryptAcquireContextA");
                if (this.cryptAcquireContextAddress == NULL)
                    goto fallBackOnRtlGenRandom;
                if (this.cryptReleaseContextAddress == NULL)
                    this.cryptReleaseContextAddress = GetProcAddress(this.advapi32, "CryptReleaseContext");

                this.cryptGenRandomAddress = GetProcAddress(this.advapi32, "CryptGenRandom");
                if (this.cryptGenRandomAddress == NULL)
                    goto fallBackOnRtlGenRandom;

                {
                    // REVIEW: Make sure this does not leave behind a bunch of keys in your profile.
                    extern (Windows) BOOL function (HCRYPTPROV *phProv, typeof(null) pszContainer, typeof(null) pszProvider, DWORD dwProvType, DWORD dwFlags) CryptAcquireContext
                        = cast(BOOL function (HCRYPTPROV *phProv, typeof(null) pszContainer, typeof(null) pszProvider, DWORD dwProvType, DWORD dwFlags)) this.cryptAcquireContextAddress;
                    if (!CryptAcquireContext(&(this.cryptographicServiceProviderHandle), NULL, NULL, 1u, 0u))
                        goto fallBackOnRtlGenRandom;
                }

                if (this.cryptographicServiceProviderHandle != NULL)
                    goto fallBackOnRtlGenRandom;
                return; // If we have a viable CSPRNG function, then we're done.

            // Otherwise, fall back on the really old RtlGenRandom API
            fallBackOnRtlGenRandom:
                this.rtlGenRandomAddress = GetProcAddress(this.advapi32, "SystemFunction036");
                if (this.rtlGenRandomAddress == NULL)
                    throw new CSPRNGException
                    (
                        "This exception was thrown because you attempted to generate " ~
                        "cryptographically secure random bytes from the csprng library, " ~
                        "but none of the Windows cryptography functions could be loaded " ~
                        "from advapi32.dll, which was the backup plan, since loading " ~
                        "Bcrypt.dll failed. " ~
                        "Ensure that either Bcrypt.dll or advapi32.dll is either in " ~
                        "the executable's directory, current directory, the Windows " ~
                        "directory, the System directory, or in one of the directories " ~
                        "in the PATH environment variable. If you believe you have " ~
                        "received this error by mistake, please report this as a bug " ~
                        "to https://github.com/JonathanWilbur/csprng-d/issues. The " ~
                        "Windows error code associated with this particular failure is " ~
                        text(GetLastError()) ~ "."
                    );
        }

        /**
            Upon deleting the $(D CSPRNG) object, the libraries used are unloaded,
            and any relevant cryptographic constructs used by those libraries
            are released.
        */
        public @system
        ~this ()
        {
            if (this.isUsingCNGAPI)
            {
                extern (Windows) NTSTATUS function (BCRYPT_ALG_HANDLE hAlgorithm, ULONG dwFlags) BCryptCloseAlgorithmProvider =
                    cast(NTSTATUS function (BCRYPT_ALG_HANDLE hAlgorithm, ULONG dwFlags)) this.bCryptCloseAlgorithmProviderAddress;
                BCryptCloseAlgorithmProvider(this.cngProviderHandle, 0u);
                FreeLibrary(this.bcrypt);
            }
            else if (this.isUsingCryptoAPI)
            {
                extern (Windows) BOOL function (HCRYPTPROV hProv, DWORD dwFlags) CryptReleaseContext =
                    cast(BOOL function (HCRYPTPROV hProv, DWORD dwFlags)) this.cryptReleaseContextAddress;
                CryptReleaseContext(this.cryptographicServiceProviderHandle, 0u);
                FreeLibrary(this.advapi32);
            }
            else if (this.isUsingRtlGenRandom)
            {
                FreeLibrary(this.advapi32);
            }
        }
    }
    else version (SecureARC4Random)
    {
        /**
            Returns the specified number of cryptographically-secure
            pseudo-random bytes, using one of the system APIs.
        */
        public @system
        void[] getBytes (in size_t length)
        {
            void[] ret = new void[length];
            arc4random_buf(ret.ptr, length);
            return ret;
        }
    }
    else version (Posix)
    {
        import std.stdio : File;

        /// The size of the buffer used to read from $(MONO /dev/random)
        public static immutable size_t readBufferSize = 128u;
        private static File randomFile;

        /**
            Returns the specified number of cryptographically-secure
            pseudo-random bytes, using one of the system APIs.
        */
        public @system
        void[] getBytes (in size_t length)
        {
            void[] ret;
            if (length <= this.readBufferSize)
                return this.randomFile.rawRead(new void[this.readBufferSize])[0 .. length];

            for (size_t i = 0u; i < (length / this.readBufferSize); i++)
            {
                ret ~= this.randomFile.rawRead(new void[this.readBufferSize]);
            }
            ret ~= this.randomFile.rawRead(new void[this.readBufferSize])[0 .. (length % this.readBufferSize)];
            return ret;
        }

        /**
            The constructor for a CSPRNG. When a $(D CSPRNG) is created with
            this constructor, the pseudo-device, $(MONO /dev/random) is opened
            for reading (not writing). If it cannot be opened, the constructor
            throws a $(D CSPRNGException) and the $(D CSPRNG) will not be created.
        */
        public @safe
        this ()
        {
            this.randomFile = File("/dev/random", "r");
            if (this.randomFile.error())
                throw new CSPRNGException
                (
                    "This exception was thrown because you attempted to generate " ~
                    "cryptographically secure random bytes from the csprng library, " ~
                    "but the CSPRNG file, /dev/random, could not be opened for " ~
                    "reading. If you believe you have received this error by mistake, " ~
                    "please report this as a bug to " ~
                    "https://github.com/JonathanWilbur/csprng-d/issues."
                );
        }

        /**
            Upon deleting the $(D CSPRNG) object, the file descriptor for the
            pseudo-device, $(MONO /dev/random) is closed. Note that it is closed
            in such a way that should not cause problems if it is closed multiple
            times.
        */
        public @safe
        ~this ()
        {
            // Used instead of close() to ensure that other CSPRNGs don't close for all others.
            this.randomFile.detach();
        }
    }
    else
    {
        static assert
        (
            0u,
            "The csprng library cannot be compiled, because your operating system " ~
            "is unsupported. The csprng library, currently, can only compile on " ~
            "Windows, Mac OS X, Linux, and possibly Solaris and the BSDs."
        );
    }
}