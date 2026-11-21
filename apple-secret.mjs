// Gera o "Secret Key (for OAuth)" que o Supabase pede para o login com a Apple.
// Uso:  node apple-secret.mjs TEAM_ID KEY_ID SERVICES_ID caminho/AuthKey_XXXX.p8
// Exemplo: node apple-secret.mjs ABCDE12345 FGHIJ67890 com.exemplo.pianomaps.web AuthKey_FGHIJ67890.p8
// O resultado dura 6 meses (limite da Apple): volta a correr isto e cola o novo valor no Supabase antes de expirar.
import fs from "fs";
import crypto from "crypto";
const [, , teamId, keyId, servicesId, p8] = process.argv;
if (!teamId || !keyId || !servicesId || !p8) { console.error("Uso: node apple-secret.mjs TEAM_ID KEY_ID SERVICES_ID ficheiro.p8"); process.exit(1); }
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
const now = Math.floor(Date.now() / 1000);
const head = b64({ alg: "ES256", kid: keyId, typ: "JWT" });
const body = b64({ iss: teamId, iat: now, exp: now + 15777000, aud: "https://appleid.apple.com", sub: servicesId });
const sig = crypto.sign("sha256", Buffer.from(head + "." + body), { key: fs.readFileSync(p8, "utf8"), dsaEncoding: "ieee-p1363" }).toString("base64url");
console.log(head + "." + body + "." + sig);
