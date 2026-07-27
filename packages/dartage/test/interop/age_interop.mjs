// Interop harness for the Dart age implementation, driving the TypeScript
// `age-encryption` npm package installed at packages/cli/node_modules.
//
// Usage (stdin/stdout carry base64 unless noted):
//   node age_interop.mjs keygen
//     -> prints "<identity>\n<recipient>\n"
//   node age_interop.mjs recipient <identity>
//     -> prints "<recipient>\n"
//   node age_interop.mjs encrypt <recipient> [<recipient> ...]
//     stdin: base64 plaintext -> stdout: armored ciphertext (ASCII)
//   node age_interop.mjs decrypt <identity>
//     stdin: armored ciphertext (ASCII) -> stdout: base64 plaintext

// Resolve the package relative to this file so the script works regardless of
// the working directory (the harness has its own package.json here; run
// `pnpm install` in this directory to materialize node_modules).
const agePackageUrl = new URL(
  "./node_modules/age-encryption/dist/index.js",
  import.meta.url,
);
const {
  Encrypter,
  Decrypter,
  armor,
  generateIdentity,
  generateHybridIdentity,
  identityToRecipient,
} = await import(agePackageUrl.href);
const { bech32, base64nopad } = await import("@scure/base");
const { p256 } = await import("@noble/curves/nist.js");
const { MLKEM768P256 } = await import("@noble/post-quantum/hybrid.js");
const { sha256 } = await import("@noble/hashes/sha2.js");
const { extract, expand } = await import("@noble/hashes/hkdf.js");
const { randomBytes } = await import("@noble/hashes/utils.js");
const { chacha20poly1305 } = await import("@noble/ciphers/chacha.js");

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks);
}

const textEncoder = new TextEncoder();

function concatBytes(...parts) {
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function hpkeLabeledExtract(suiteID, salt, label, ikm) {
  return extract(
    sha256,
    concatBytes(textEncoder.encode("HPKE-v1"), suiteID, textEncoder.encode(label), ikm),
    salt,
  );
}

function hpkeLabeledExpand(suiteID, prk, label, info, length) {
  return expand(
    sha256,
    prk,
    concatBytes(
      new Uint8Array([length >> 8, length & 0xff]),
      textEncoder.encode("HPKE-v1"),
      suiteID,
      textEncoder.encode(label),
      info,
    ),
    length,
  );
}

function hpkeContext(kemID, sharedSecret, label) {
  const suiteID = concatBytes(
    textEncoder.encode("HPKE"),
    new Uint8Array([kemID >> 8, kemID & 0xff, 0, 1, 0, 3]),
  );
  const empty = new Uint8Array();
  const pskIDHash = hpkeLabeledExtract(suiteID, undefined, "psk_id_hash", empty);
  const infoHash = hpkeLabeledExtract(suiteID, undefined, "info_hash", label);
  const context = concatBytes(new Uint8Array([0]), pskIDHash, infoHash);
  const secret = hpkeLabeledExtract(suiteID, sharedSecret, "secret", empty);
  return {
    key: hpkeLabeledExpand(suiteID, secret, "key", context, 32),
    nonce: hpkeLabeledExpand(suiteID, secret, "base_nonce", context, 12),
  };
}

function p256KemSharedSecret(secretKey, encapsulatedKey, recipient) {
  const raw = p256.getSharedSecret(secretKey, encapsulatedKey, true).subarray(1);
  const suiteID = concatBytes(textEncoder.encode("KEM"), new Uint8Array([0, 0x10]));
  const eaePRK = hpkeLabeledExtract(suiteID, undefined, "eae_prk", raw);
  return hpkeLabeledExpand(
    suiteID,
    eaePRK,
    "shared_secret",
    concatBytes(encapsulatedKey, recipient),
    32,
  );
}

function equalBytes(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function tagIdentity(kind, secretKey) {
  const hybrid = kind === "hybrid-tag";
  const type = hybrid ? "mlkem768p256tag" : "p256tag";
  const kemID = hybrid ? 0x0050 : 0x0010;
  const label = textEncoder.encode(
    hybrid
      ? "age-encryption.org/mlkem768p256tag"
      : "age-encryption.org/p256tag",
  );
  const recipient = hybrid
    ? MLKEM768P256.getPublicKey(secretKey)
    : p256.getPublicKey(secretKey, true);
  const recipientForTag = hybrid ? recipient.subarray(1184) : recipient;
  return {
    unwrapFileKey(stanzas) {
      for (const stanza of stanzas) {
        if (stanza.args[0] !== type) continue;
        if (stanza.args.length !== 3 || stanza.body.length !== 32) {
          throw new Error(`invalid ${type} stanza`);
        }
        const tag = base64nopad.decode(stanza.args[1]);
        const encapsulatedKey = base64nopad.decode(stanza.args[2]);
        const recipientHash = sha256(recipientForTag).subarray(0, 4);
        const expectedTag = extract(
          sha256,
          concatBytes(encapsulatedKey, recipientHash),
          label,
        ).subarray(0, 4);
        if (!equalBytes(tag, expectedTag)) continue;
        const sharedSecret = hybrid
          ? MLKEM768P256.decapsulate(encapsulatedKey, secretKey)
          : p256KemSharedSecret(secretKey, encapsulatedKey, p256.getPublicKey(secretKey, false));
        const { key, nonce } = hpkeContext(kemID, sharedSecret, label);
        try {
          return chacha20poly1305(key, nonce).decrypt(stanza.body);
        } catch {
          continue;
        }
      }
      return null;
    },
  };
}

const [, , command, ...args] = process.argv;

switch (command) {
  case "keygen": {
    const identity = await generateIdentity();
    const recipient = await identityToRecipient(identity);
    process.stdout.write(`${identity}\n${recipient}\n`);
    break;
  }
  case "hybrid-keygen": {
    const identity = await generateHybridIdentity();
    const recipient = await identityToRecipient(identity);
    process.stdout.write(`${identity}\n${recipient}\n`);
    break;
  }
  case "tag-keygen": {
    const secretKey = p256.utils.randomSecretKey();
    const recipient = bech32.encode(
      "age1tag",
      bech32.toWords(p256.getPublicKey(secretKey, true)),
      false,
    );
    process.stdout.write(`${Buffer.from(secretKey).toString("hex")}\n${recipient}\n`);
    break;
  }
  case "hybrid-tag-keygen": {
    const secretKey = randomBytes(32);
    const recipient = bech32.encode(
      "age1tagpq",
      bech32.toWords(MLKEM768P256.getPublicKey(secretKey)),
      false,
    );
    process.stdout.write(`${Buffer.from(secretKey).toString("hex")}\n${recipient}\n`);
    break;
  }
  case "recipient": {
    const recipient = await identityToRecipient(args[0]);
    process.stdout.write(`${recipient}\n`);
    break;
  }
  case "encrypt": {
    const plaintext = Buffer.from((await readStdin()).toString("ascii"), "base64");
    const encrypter = new Encrypter();
    for (const recipient of args) encrypter.addRecipient(recipient);
    const ciphertext = await encrypter.encrypt(new Uint8Array(plaintext));
    process.stdout.write(armor.encode(ciphertext));
    break;
  }
  case "decrypt": {
    const armored = (await readStdin()).toString("ascii");
    const decrypter = new Decrypter();
    for (const identity of args) decrypter.addIdentity(identity);
    const plaintext = await decrypter.decrypt(armor.decode(armored));
    process.stdout.write(Buffer.from(plaintext).toString("base64"));
    break;
  }
  case "encrypt-passphrase": {
    const plaintext = Buffer.from((await readStdin()).toString("ascii"), "base64");
    const encrypter = new Encrypter();
    encrypter.setPassphrase(args[0]);
    encrypter.setScryptWorkFactor(Number(args[1] ?? "10"));
    const ciphertext = await encrypter.encrypt(new Uint8Array(plaintext));
    process.stdout.write(armor.encode(ciphertext));
    break;
  }
  case "decrypt-passphrase": {
    const armored = (await readStdin()).toString("ascii");
    const decrypter = new Decrypter();
    decrypter.addPassphrase(args[0]);
    const plaintext = await decrypter.decrypt(armor.decode(armored));
    process.stdout.write(Buffer.from(plaintext).toString("base64"));
    break;
  }
  case "decrypt-tag": {
    const armored = (await readStdin()).toString("ascii");
    const decrypter = new Decrypter();
    decrypter.addIdentity(tagIdentity(args[0], Buffer.from(args[1], "hex")));
    const plaintext = await decrypter.decrypt(armor.decode(armored));
    process.stdout.write(Buffer.from(plaintext).toString("base64"));
    break;
  }
  default:
    process.stderr.write(`unknown command: ${command}\n`);
    process.exit(2);
}
