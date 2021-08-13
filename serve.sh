#!/bin/sh
if [ ! -d "node_modules" ]; then
	echo First Time Setup.
	npm install
	mkdir db
fi
#
node --unhandled-rejections=strict app.js
while [ $? -eq 99 ]
do
	node --unhandled-rejections=strict app.js
done
