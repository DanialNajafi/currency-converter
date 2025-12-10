import { parseArgs } from "@std/cli/parse-args";
import { isCurrency } from "./validation.ts";
import { Converter } from "./conversion.ts";

const flags = parseArgs(Deno.args, {
  string: ["rates", "from", "to", "amount"],
});

if (!flags.rates) {
  console.error("--rates file required");
  Deno.exit(1);
}
const rates = JSON.parse(Deno.readTextFileSync(flags.rates));

if (!flags.from || !isCurrency(flags.from)) {
  console.error("--from must be three-letter lower-case currency symbol");
  Deno.exit(1);
}
if (!flags.to || !isCurrency(flags.to)) {
  console.error("--to must be three-letter lower-case currency symbol");
  Deno.exit(1);
}

if (!flags.amount) {
  console.error("--amount must be a currency amount");
  Deno.exit(1);
}
const amount = Number.parseFloat(flags.amount);

const converter = new Converter();
for (const { fromCurrency, toCurrency, exchangeRate } of rates) {
  converter.setRate(fromCurrency, toCurrency, exchangeRate);
}

const result = converter.convert(flags.from, flags.to, amount);
console.log(result);
