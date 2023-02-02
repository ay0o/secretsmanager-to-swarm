#!/bin/bash

pip3 install -r requirements.txt -t ./dependencies
cd dependencies
zip -r ../lambda.zip .
cd ..
zip lambda.zip app.py