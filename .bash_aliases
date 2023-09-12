# alias apt='nala'

alias port='port -c 5'

vpncheck(){ echo "     Host IP: $(wget -qO- ifconfig.me)" && echo "Container IP: $(docker container exec -it "${*}" wget -qO- ipinfo.io/ip)"; }
ipcheck(){ echo "Container IP: $(docker container exec -it "${*}" wget -qO- ipinfo.io)"; }

appdata(){ cd /share/docker/appdata/${1} || return; }
compose(){ cd /share/docker/compose/${1} || return; }

docker_list_containers(){ docker container list --format "table {{.ID}}  {{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}"; }
alias dlc="docker_list_containers"

export var_uid="$(id -u docker)"
export var_gid="$(id -g docker)"

docker_compose_folders(){
    install -o $var_uid -g $var_gid -m 774 -d /share/docker/{appdata,compose}/${1}
    install -o $var_uid -g $var_gid -m 660 /dev/null /share/docker/compose/${1}/compose.yml
    # install -o 1000 -g 1000 -m 774 /dev/null /opt/docker/compose/$1/.env
    ln -sf /share/docker/compose/${1}/.env /share/docker/.docker.env
    }
alias dcf='docker_compose_folders'

docker_compose_up(){ docker-compose -f /share/docker/compose/${1}/compose.yml up -d --remove-orphans; }
alias dcu="docker_compose_up"

docker_compose_down(){ docker-compose -f /share/docker/compose/${1}/compose.yml down; }
alias dcd="docker_compose_down"
