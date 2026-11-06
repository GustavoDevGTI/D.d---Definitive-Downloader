"""Legacy recording blocks; account credentials continue to use the OS vault."""


def block_decoder(key):
    try:
        from Crypto.Cipher import Blowfish
    except ImportError:
        # Android bundles the pinned pure-Python implementation: no Windows
        # extension module is copied to the APK. Expand this recording key once.
        import blowfish
        cipher = blowfish.Cipher(key)

        def decrypt(data, iv):
            return b''.join(cipher.decrypt_cbc(data, iv))
        return decrypt

    def decrypt(data, iv):
        return Blowfish.new(key, Blowfish.MODE_CBC, iv).decrypt(data)
    return decrypt
