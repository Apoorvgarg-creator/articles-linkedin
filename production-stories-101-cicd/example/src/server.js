import http from 'node:http';
import { handle } from './app.js';

const port = Number(process.env.PORT || 3000);

http
  .createServer((req, res) => {
    const { status, body } = handle(req);
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  })
  .listen(port, () => console.log(`listening on :${port}`));
