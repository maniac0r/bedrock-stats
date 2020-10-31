player2name() {
  player=$1

  case $player in
  BossFrog6157994)
    nick="Boss Frog"
  ;;

  Emma4576)
    nick="Linda"
  ;;

  FearlessTomy)
    nick="Tommy"
  ;;

  maniac0r)
    nick="Maniac"
  ;;

  Marty333333333)
    nick="Marty 3"
  ;;

  MartY4684)
    nick="Marty 4"
  ;;

  NinkaKlara)
    nick="Nina"
  ;;

  Pukaco)
    nick="Pookatscho"
  ;;

  Tyrkys18)
    nick="Tyrkys"
  ;;

  esac

  if [ -z "$nick" ] ; then
    nick=$player
  fi

  echo "$nick"

}
