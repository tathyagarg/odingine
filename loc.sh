#!/bin/bash

res=$(curl -s -L "https://api.codetabs.com/v1/loc?github=tathyagarg/odingine&ignored=third_party" | jq '.[] | select(.language == "Total") | "\(.files) \(.lines)"')

read FILES LINES <<<$res

echo "${LINES//\"/} lines of code, over ${FILES//\"/} files"
