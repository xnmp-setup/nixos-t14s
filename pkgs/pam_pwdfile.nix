{ lib, stdenv, fetchFromGitHub, pam, libxcrypt }:

# pam_pwdfile — authenticates against a flat /etc/passwd-style file instead of
# the system password database. Not in nixpkgs, so it is built here.
#
# Provenance, deliberately recorded because this lands in the PAM auth path:
#   original author  Charl P. Botha, 3-clause BSD
#   maintained fork  github.com/tiwe-de/libpam-pwdfile (Timo Weingärtner)
#   v1.0 tag dates from 2013; the repo was archived read-only in 2018.
# It is unmaintained upstream and receives no security fixes. It is used here
# only for hyprlock, never for login/sudo/ssh — see modules/hyprland.nix.
stdenv.mkDerivation {
  pname = "pam_pwdfile";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "tiwe-de";
    repo = "libpam-pwdfile";
    rev = "v1.0";
    hash = "sha256-/gP/iG332hVJCiDw7+b83FIEX1pb1mfj6uAFR63mX2o=";
  };

  # -lcrypt: glibc dropped libcrypt, so the crypt(3) impl comes from libxcrypt.
  buildInputs = [ pam libxcrypt ];

  # The 2013 sources call crypt(3) relying on unistd.h to declare it. Modern
  # glibc does not — the declaration moved to libxcrypt's crypt.h — so the
  # compiler inferred `int crypt()` and truncated the returned char* to 32 bits.
  # GCC 14 promotes that to a hard error, which is how it surfaced. Force the
  # real prototype in rather than silencing the diagnostic: -Wno-int-conversion
  # would have "fixed" the build and left the pointer truncation in place.
  env.NIX_CFLAGS_COMPILE = "-include crypt.h";

  # Upstream defaults PAM_LIB_DIR to /lib/security, which is not writable and
  # not where NixOS looks. Point it at $out and let the install target do the rest.
  makeFlags = [ "PAM_LIB_DIR=${placeholder "out"}/lib/security" ];

  meta = with lib; {
    description = "PAM module for authenticating against an /etc/passwd-like file";
    homepage = "https://github.com/tiwe-de/libpam-pwdfile";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}
