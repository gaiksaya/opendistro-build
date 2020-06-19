#!/bin/bash

set -e
REPO_ROOT=`git rev-parse --show-toplevel`
ES_VER=`$REPO_ROOT/bin/version-info --es`
ODFE_VER=`$REPO_ROOT/bin/version-info --od`
echo $ES_VER $ODFE_VER

if [ "$#" -eq 0 ] || [ "$#" -gt 2 ]
then
    echo "Please assign at least 1 and at most 2 parameters when running this script"
    echo "Example: $0 [\$DISTRIBUTION_TYPE] [\$ENABLE]"
    echo "Example: $0 \"RPM\""
    echo "Example: $0 \"RPM\" \"ENABLE\""
    exit 1
fi

if [ "$1" = "RPM" ]
then
###### RPM package with Security enabled ######

#installing ODFE
cat <<- EOF > $REPO_ROOT/userdata_$1.sh
#!/bin/bash
sudo -i
sudo curl https://d3g5vo6xdbdb9a.cloudfront.net/yum/staging-opendistroforelasticsearch-artifacts.repo -o /etc/yum.repos.d/staging-opendistroforelasticsearch-artifacts.repo
sudo yum install -y opendistroforelasticsearch-$ODFE_VER
sudo sysctl -w vm.max_map_count=262144
echo "node.name: init-master" >> /etc/elasticsearch/elasticsearch.yml
echo "cluster.name: odfe-$ODFE_VER-rpm-auth" >> /etc/elasticsearch/elasticsearch.yml
echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
echo "cluster.initial_master_nodes: [\"init-master\"]" >> /etc/elasticsearch/elasticsearch.yml
sed -i 's/-Xms1g/-Xms6g/' /etc/elasticsearch/jvm.options
sed -i 's/-Xms1g/-Xms6g/' /etc/elasticsearch/jvm.options
sed -i 's/-Xmx1g/-Xmx6g/' /etc/elasticsearch/jvm.options

# Start the service
sudo systemctl start elasticsearch.service
sleep 30

# Installing kibana
sudo yum install -y opendistroforelasticsearch-kibana-$ODFE_VER
echo "server.host: 0.0.0.0" >> /etc/kibana/kibana.yml
sudo systemctl start kibana.service
EOF
fi

if [ "$1" = "DEB" ]
then 
###### DEB package with Security enabled ######
cat <<- EOF > $REPO_ROOT/userdata_$1.sh
#!/bin/bash
#installing ODFE
sudo -i
sudo sysctl -w vm.max_map_count=262144
sudo apt-get install -y zip
wget -qO - https://d3g5vo6xdbdb9a.cloudfront.net/GPG-KEY-opendistroforelasticsearch | sudo apt-key add -
echo "deb https://d3g5vo6xdbdb9a.cloudfront.net/staging/apt stable main" | sudo tee -a /etc/apt/sources.list.d/opendistroforelasticsearch.list

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-$ES_VER-amd64.deb
sudo dpkg -i elasticsearch-oss-$ES_VER-amd64.deb
sudo apt-get -y update
sudo apt install -y opendistroforelasticsearch
echo "node.name: init-master" >> /etc/elasticsearch/elasticsearch.yml
echo "cluster.initial_master_nodes: [\"init-master\"]" >> /etc/elasticsearch/elasticsearch.yml
echo "cluster.name: odfe-$ODFE_VER-deb-auth" >> /etc/elasticsearch/elasticsearch.yml
echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
sed -i 's/-Xms1g/-Xms6g/' /etc/elasticsearch/jvm.options
sed -i 's/-Xmx1g/-Xmx6g/' /etc/elasticsearch/jvm.options
# Start the service
sudo systemctl start elasticsearch.service
sleep 30

# Installing kibana
sudo apt install opendistroforelasticsearch-kibana
echo "server.host: 0.0.0.0" >> /etc/kibana/kibana.yml
sudo systemctl start kibana.service

EOF
fi

if [ "$1" = "TAR" ]
then 
###### TAR package with Security enabled ######
cat <<- EOF > $REPO_ROOT/userdata_$1.sh
#!/bin/bash
sudo sysctl -w vm.max_map_count=262144
sudo apt-get install -y zip
wget https://d3g5vo6xdbdb9a.cloudfront.net/downloads/tarball/opendistro-elasticsearch/opendistroforelasticsearch-$ODFE_VER.tar.gz
tar zxvf opendistroforelasticsearch-$ODFE_VER.tar.gz
cd opendistroforelasticsearch-$ODFE_VER/

echo "node.name: init-master" >> config/elasticsearch.yml
echo "cluster.initial_master_nodes: [\"init-master\"]" >> config/elasticsearch.yml
echo "cluster.name: odfe-$ODFE_VER-tarball-auth" >> config/elasticsearch.yml
echo "network.host: 0.0.0.0" >> config/elasticsearch.yml
sed -i 's/-Xms1g/-Xms6g/' config/jvm.options
sed -i 's/-Xmx1g/-Xmx6g/' config/jvm.options

nohup ./opendistro-tar-install.sh 2>&1 > /dev/null &

#Installing kibana
wget https://d3g5vo6xdbdb9a.cloudfront.net/downloads/tarball/opendistroforelasticsearch-kibana/opendistroforelasticsearch-kibana-$ODFE_VER.tar.gz
tar zxvf opendistroforelasticsearch-kibana-$ODFE_VER.tar.gz
cd opendistroforelasticsearch-kibana/
echo "server.host: 0.0.0.0" >> config/kibana.yml

nohup ./bin/kibana &
EOF
fi

#### Security disable feature ####
if  [[ "$2" = "DISABLE" ]]
then
    if [[ "$1" = "RPM"  ||  "$1" = "DEB" ]]
    then
      sed -i 's/^echo \"cluster.name.*/echo \"cluster.name \: odfe-\$ODFE_VER-\$1-noauth\" \>\> \/etc\/elasticsearch\/elasticsearch.yml/g' userdata_$1.sh
      sed -i '/echo \"network.host/a echo \"opendistro_security.disabled: true\" \>\> \/etc\/elasticsearch\/elasticsearch.yml' userdata_$1.sh
     else
      sed -i 's/^echo \"cluster.name.*/echo \"cluster.name \: odfe-\$ODFE_VER-\$1-noauth\" \>\> config\/elasticsearch.yml/g' userdata_$1.sh
      sed -i '/echo \"network.host/a echo \"opendistro_security.disabled: true\" \>\> config\/elasticsearch.yml' userdata_$1.sh
    fi
fi
