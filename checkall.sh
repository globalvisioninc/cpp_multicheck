#!/bin/bash

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "The GITHUB_TOKEN is required."
	exit 1
fi

echo "Event path: $GITHUB_EVENT_PATH"
FILES_LINK=`jq -r '.pull_request._links.self.href' "$GITHUB_EVENT_PATH"`/files
echo "Files = $FILES_LINK"
curl -H "Authorization: token $GITHUB_TOKEN" $FILES_LINK > files.json
JSON_DEBUG=`cat files.json`
echo "Json file:"
echo "$JSON_DEBUG"
FILES_URLS_STRING=`jq -r '.[].contents_url' files.json`

readarray -t URLS <<<"$FILES_URLS_STRING"

echo "File names: $URLS"

mkdir files
cd files
for i in "${URLS[@]}"
do
	echo "Downloading $i"
	#curl -u naubryGV:$GITHUB_TOKEN -s $i
	#echo "Name without web params: ${i%%\?*}"
	curl -H "Authorization: token $GITHUB_TOKEN" --header "Accept: application/vnd.github.v3.raw" --header "User-Agent: ${OWNER}/${REPO} (curl v7.47.0)" -L --remote-name $i
	#--remote-name
	#-o ${i%%\?*}
done

echo "Files downloaded!"
ls -la
