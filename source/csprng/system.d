/**
    System sources for randomness.
*/
module csprng.system;
import std.conv : text;

// TODO: Check for STATUS_SUCCESS, not just true

///
public alias CSPRNG = CryptographicallySecurePseudoRandomNumberGenerator;
///
public
class CryptographicallySecurePseudoRandomNumberGenerator
{
    version (Windows)
    {
        import core.sys.windows.windows;

        // REVIEW: Could this result in these data structures overwriting other stuff?
        // REVIEW: Should I call malloc() before using these pointers to store data?
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
        ///
        public @property
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
        ///
        public @property
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

        ///
        public @property
        bool isUsingRtlGenRandom()
        {
            return
            (
                this.advapi32 != NULL &&
                this.rtlGenRandomAddress != NULL
            );
        }

        ///

        public
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
        
            throw new Exception("Could not find a function to generate random bytes!");
        }

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
                    throw new Exception("csprng library could not load advapi32.dll. Windows error code: " ~ text(GetLastError()));

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
                    throw new Exception("csprng library could not load RtlGenRandom / SystemFunction036 from advapi32.dll. Windows error code: " ~ text(GetLastError()));
        }

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
    else version (Posix)
    {
        import std.stdio : File;
        
        static size_t readBufferSize = 1000u;
        static File randomFile;

        public
        void[] getBytes (in size_t length)
        {
            void[] ret;
            void[this.readBufferSize] readBuffer;
            while (ret.length < length)
                ret ~= this.randomFile.rawRead(readBuffer);
            return ret;
        }
    
        this ()
        {
            this.randomFile = File("/dev/random", "r");
            if (this.randomFile.error())
                throw new Exception("Could not open /dev/random for reading.");
        }

        ~this ()
        {
            // Used instead of close() to ensure that other CSPRNGs don't close for all others.
            this.randomFile.detach();
        }
    }
    else
    {
        static assert (0, "Unsupported operating system. Sorry!");
    }
}