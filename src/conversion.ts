export class Converter {
  private conversionRates: Map<string, number> = new Map();

  getRate(fromCurrency: string, toCurrency: string): number | undefined {
    return this.conversionRates.get(this.toKey(fromCurrency, toCurrency));
  }

  setRate(fromCurrency: string, toCurrency: string, rate: number) {
    this.conversionRates.set(this.toKey(fromCurrency, toCurrency), rate);
    this.conversionRates.set(this.toKey(toCurrency, fromCurrency), 1.0 / rate);
  }

  removeRate(fromCurrency: string, toCurrency: string) {
    this.conversionRates.delete(this.toKey(fromCurrency, toCurrency));
    this.conversionRates.delete(this.toKey(toCurrency, fromCurrency));
  }

  convert(
    fromCurrency: string,
    toCurrency: string,
    amount: number,
  ): number | undefined {
    const key = this.toKey(fromCurrency, toCurrency);
    const rate = this.conversionRates.get(key);
    if (rate) {
      return amount * rate;
    } else {
      return undefined;
    }
  }

  toKey(fromCurrency: string, toCurrency: string): string {
    return `${fromCurrency}:${toCurrency}`;
  }
}
