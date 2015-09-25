#!/bin/bash

if [ $# -lt 1 ]; then
        echo -e "no parameters given!\n"
        echo -e 'sudo maintain <OPTIONS>'
        echo -e "<OPTIONS> are:"
        echo -e '\t\t-a "IPs+port space separated" to ADD service IPs'
        echo -e '\t\t-d "IPs+port space separated" to DELETE service IPs\n'
        echo -e '\t\t-s to SHOW all IPs with resolved names in maintenance\n'
        echo -e 'e.g.: sudo maintain.sh -a "1.2.3.4:80 5.6.7.8:443" -d "2.3.4.5:80 6.7.8.9:443"\n'
        echo -e 'e.g.: sudo maintain.sh -s\n'
        exit
fi

apache_refresh=false
apache_maintain_config="/etc/apache2/sites-enabled/maintenance.it.auth.gr.conf"
#apache_maintain_config=maintenance.it.auth.gr
eth_iface="eth0"

while getopts :a:d:s option
do
        case "${option}" in
                a)SRV_IP+=(${OPTARG})
                  for ipport in "${SRV_IP[@]}"; do
                        if [ `grep -c $ipport $apache_maintain_config` -eq 0 ]; then
                                ip=$(echo $ipport | cut -d':' -f 1)
                                #echo -e "\n#Start $ipport\nListen $ipport\n<Virtualhost $ip>\n\tServerAdmin webmaster@auth.gr\n\n\tDocumentRoot /var/www/maintenance.it.auth.gr\n\n\tLogLevel warn\n</Virtualhost>\n#End $ipport" >> $apache_maintain_config
                                echo -e "\n#Start $ipport \
                                        \n#Listen $ipport \
                                        \n<Virtualhost $ip> \
                                                \n\tServerAdmin webmaster@auth.gr \
                                                \n\tDocumentRoot /var/www/maintenance.it.auth.gr \
                                                \n\tLogLevel warn \
                                        \n</Virtualhost> \
                                        \n#End $ipport" >> $apache_maintain_config
                                echo -e "\nAdding $ip to the interface $eth_iface...\n"
                                ip addr add dev $eth_iface $ip/24
                                echo -e "Arpinging $ip...\n"
                                arping -q -I $eth_iface -c 3 -s $ip $(echo $ip | cut -d'.' -f 1-3).255
                                apache_refresh=true
                                echo "$ip of $eth_iface ADDED in maintenance config"
                        else
                                echo "$ip already in maintenance config, skipping...."
                        fi
                  done
                  ;;
                d)SRV_IP+=(${OPTARG})
                  for ipport in "${SRV_IP[@]}"; do
                        if [ `grep -c $ipport $apache_maintain_config` -gt 0 ]; then
                                sed -i '/#Start '$ipport'/,/#End '$ipport'/d' $apache_maintain_config
                                ip=$(echo $ipport | cut -d':' -f 1)
                                echo -e "Removing $ip from interface $eth_iface...\n"
                                ip addr del dev $eth_iface $(echo $ip | cut -d':' -f 1)/24
                                apache_refresh=true
                                echo "$ip of $eth_iface FOUND in maintenance config, was deleted...."
                        else
                                echo "$ip NOT found in maintenance config, skipping...."
                        fi
                  done
                  sed -i '/^$/d' $apache_maintain_config
                  echo -e "\n\n*** DON'T FORGET TO ARPING THE SERVICE(S) IP AT THE ORIGINAL VM!!!!!! ***\n\n"
                  ;;
                                  s) echo "Status of IPs in maintenance:"
                  if [ `grep -c '#Start' $apache_maintain_config` -gt 0 ]; then
                        grep '#Start' $apache_maintain_config | cut -d' ' -f 2 | cut -d':' -f 1 | while read -r line ; do
                                echo -e "\t$line - "$(host $line | rev | cut -d' ' -f 1 | rev)
                        done
                  else
                        echo -e '\n\tNo services in maintenance\n'
                  fi
                  ;;
                *) echo '$option is not a valid parameter'
                  ;;
        esac
done

if $apache_refresh; then
        service apache2 reload
fi
