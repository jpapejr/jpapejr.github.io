```
nc -lkv 4444 < myfifo | nc -Uv /var/run/docker.sock > myfifo
```