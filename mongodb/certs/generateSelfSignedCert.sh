#!/bin/bash
rm ca.key ca.pem ca.srl client.crt client.csr client.key client.pem mongodb.pem server.crt server.csr server.key
# Generate self signed root CA cert
openssl req -config openssl.cnf -days 3650 -nodes -x509 -newkey rsa:2048 -subj "/C=US/ST=NY/L=New York/O=Example, LLC/CN=Mongo CA" -extensions v3_ca -keyout ca.key -out ca.pem

# Generate server cert to be signed
openssl req -config openssl.cnf -nodes -newkey rsa:2048 -keyout server.key -out server.csr 

# Sign the server cert
openssl x509 -req -in server.csr -days 3650 -CA ca.pem -CAkey ca.key -CAcreateserial -extensions v3_req -extfile openssl.cnf -out server.crt

# Create server PEM file
cat server.key server.crt > mongodb.pem

# Generate client cert to be signed
openssl req -config openssl.cnf -subj "/C=US/ST=NY/L=New York/O=Example, LLC/CN=Mongo Client" -nodes -newkey rsa:2048 -keyout client.key -out client.csr 

# Sign the client cert
openssl x509 -req -in client.csr -days 3650 -CA ca.pem -CAkey ca.key -CAserial ca.srl -extensions v3_clnt -extfile openssl.cnf -out client.crt

# Create client PEM file
cat client.key client.crt > client.pem