{
  runCommand,
  python3,
}:
runCommand "osyx-themes" {
  nativeBuildInputs = [(python3.withPackages (p: [p.jinja2]))];
  flavors = ../../home/osyx/assets/flavors;
} ''
  mkdir -p $out
  for pal in $flavors/palettes/*.toml; do
    name=$(basename "$pal" .toml)
    work=$TMPDIR/$name
    mkdir -p "$work"
    cp -r $flavors "$work/flavors"
    chmod -R u+w "$work"
    # Le générateur écrit relativement au parent de flavors/
    (cd "$work/flavors" && python3 generate.py "$name")
    rm -rf "$work/flavors"
    cp -r "$work" "$out/$name"
  done
''
