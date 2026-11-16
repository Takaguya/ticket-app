# Certificate for nginx

nginx reads two files from this folder (it cannot start without them):

- `fullchain.pem`: your certificate followed by the issuer's chain
- `privkey.pem`: its private key

They are never committed (`.gitignore`) and never copied into an image: the folder is mounted
read-only into the nginx container.

The certificate must be for the name in `PIN_DOMAIN` (the address the apps use).

## With Let's Encrypt, on the server (certbot)

Run this once, with port 80 free, before starting the compose project:

```
sudo certbot certonly --standalone -d api.example.com
sudo cp /etc/letsencrypt/live/api.example.com/fullchain.pem nginx/certs/
sudo cp /etc/letsencrypt/live/api.example.com/privkey.pem   nginx/certs/
docker compose -f compose.prod.yaml up -d --build
```

Certificates last 90 days. To renew, run `sudo certbot renew`, copy the two files again and run
`docker compose -f compose.prod.yaml restart nginx`. (A `--deploy-hook` script in certbot can do the
copy and restart for you.)

## With another certificate

A Cloudflare origin certificate or one you bought works the same way: save it as `fullchain.pem`
and its key as `privkey.pem`.

## Just to try it on your own machine

```
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=localhost" \
  -keyout privkey.pem -out fullchain.pem
```

and set `PIN_DOMAIN=localhost`. The apps will not trust a certificate like this; `curl -k` will.
