{ stdenv, fetchzip }:

stdenv.mkDerivation {
  name = "google-sans";
  src = fetchzip {
    url = "https://flutter.googlesource.com/gallery-assets/+archive/refs/heads/master/lib/fonts.tar.gz";
    stripRoot = false;
    hash = "sha256-Q879GxbRa+E6KSqG9BcNHH5M2I6RBwnzeeH6F1J1Cv4=";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp GoogleSans*.ttf $out/share/fonts/truetype/
  '';
}
