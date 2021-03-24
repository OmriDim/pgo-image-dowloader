#!/bin/bash

# Example for the Docker Hub V2 API
# Returns all images and tags associated with a Docker Hub organization account.
# Requires 'jq': https://stedolan.github.io/jq/

# set username, password, and organization
UNAME="" # add user 
UPASS="" # add password
operator_versions="" # add wanted operator version
old_version="" # add old operator version
ORG="crunchydata"
image_dir='/mnt/'

# -------
# check supported versions
if [[ $operator_version == "4.6.1" ]]; then
  postgres_versions=('13.2' '12.6' '11.11' '10.16' '9.6.21')	
elif [[ $operator_version == "4.5.1" ]]; then
  postgres_versions=('11.10' '10.15' '9.6.20' '9.5.24') #'13.1' '12.5'
else
  echo "operator version is not supported" && exit
fi
old_version=${postgres_versions[0]}

set -e
echo

# get token
echo "Retrieving token ..."
TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${UNAME}'", "password": "'${UPASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

# get list of repositories
echo "Retrieving repository list ..."
REPO_LIST=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${ORG}/?page_size=100 | jq -r '.results|.[]|.name')

# output images & tags
echo
echo "Images and tags for organization: ${ORG}"
echo
# iterate over repos
for repo in ${REPO_LIST}; do
  echo "${repo}:"
  # tags
  IMAGE_TAGS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${ORG}/${repo}/tags/?page_size=100 | jq -r '.results|.[]|.name')
  # iterate over the  tags
  for tag in ${IMAGE_TAGS}; do
    # check tag's operator version 
    if [[ $tag == *"$operator_version"* ]]; then
      # iterate over all of the relevant postgres versions
      for version in ${postgres_versions[@]}; do
      echo "downloading image tag: ${repo}:${tag/$old_version/$version}"
      docker pull -q  registry.developers.crunchydata.com/crunchydata/${repo}:${tag/${old_version}/${version}} || docker pull -q docker.io/crunchydata/${repo}:${tag/${old_version}/${version}} && echo  || echo epic fail while pulling 2>/dev/null
      docker save -q registry.developers.crunchydata.com/crunchydata/${repo}:${tag/${old_version}/${version}} > ${image_dir}/${repo}:${tag/${old_version}/${version}}.tar || docker save -q docker.io/crunchydata/${repo}:${tag/${old_version}/${version}} > ${image_dir}/${repo}:${tag/{$old_version}/${version}}.tar && echo successful save || echo epic fail while saving 2>/dev/null
      done
    fi
  done
  echo
done

