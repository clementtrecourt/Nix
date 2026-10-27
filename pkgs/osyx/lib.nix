{
  pkgs,
  inputs,
}: let
  mango = inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.mango;
in {
  # Recharge la config Mango en cours d'exécution (vérifié avec `mmsg -h`).
  mmsgReload = "${mango}/bin/mmsg dispatch reload_config";
}
