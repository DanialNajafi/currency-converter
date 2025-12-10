import { decodeBase64 } from "@std/encoding/base64";
import { RequestParam } from "./types.ts";

export function authenticate(r: Request): boolean {
  const auth = r.headers.get("authorization") || "";
  const match = /^Basic ([A-Za-z0-9+/]+)=*$/.exec(auth);
  if (match === null) {
    return false;
  }
  const usernamePassword = new TextDecoder().decode(decodeBase64(match[1]));
  const [username, password] = usernamePassword.split(":");
  return username == credentials.username && password == credentials.password;
}

export function getRate(_req: Request, data: RequestParam): Response {
  console.log(data);
  return new Response("getRate");
}

export function putRate(_req: Request, data: RequestParam): Response {
  console.log(data);
  return new Response("putRate");
}

export function deleteRate(_req: Request, data: RequestParam): Response {
  console.log(data);
  return new Response("deleteRate");
}

export function getConversion(_req: Request, data: RequestParam): Response {
  console.log(data);
  return new Response("getConversion");
}

const credentials = {
  username: "banker",
  password: "iLikeMoney",
};
