import { RequestParam, RouteParam } from "./types.ts";
import {
  authenticate,
  getConversion,
  getRate,
  putRate,
  deleteRate,
} from "./endpoints.ts";

// GET /rate/{fromCurrency}/{toCurrency}
// PUT /rate/{fromCurrency}/{toCurrency}/{value}
// DELETE /rate/{fromCurrency}/{toCurrency}
// GET /conversion/{fromCurrency}/{toCurrency}/{value}
export const routes: Array<RouteParam> = [
  {
    method: "GET",
    pattern: new RegExp("^/rate/([a-z]{3})/([a-z]{3})$", "i"),
    capture: (m: Array<string>): RequestParam => {
      return { fromCurrency: m[1], toCurrency: m[2], value: 0.0 };
    },
    authenticate: (_) => true,
    handle: getRate,
  },
  {
    method: "PUT",
    pattern: new RegExp(
      "^/rate/([a-z]{3})/([a-z]{3})/([0-9]*\\.?[0-9]+)$",
      "i",
    ),
    capture: (m: Array<string>): RequestParam => {
      return {
        fromCurrency: m[1],
        toCurrency: m[2],
        value: Number.parseFloat(m[3]),
      };
    },
    authenticate: authenticate,
    handle: putRate,
  },
  {
    method: "DELETE",
    pattern: new RegExp("^/rate/([a-z]{3})/([a-z]{3})$", "i"),
    capture: (m: Array<string>): RequestParam => {
      return { fromCurrency: m[1], toCurrency: m[2], value: 0.0 };
    },
    authenticate: authenticate,
    handle: deleteRate,
  },
  {
    method: "GET",
    pattern: new RegExp(
      "^/conversion/([a-z]{3})/([a-z]{3})/([0-9]*\\.?[0-9]+)$",
      "i",
    ),
    capture: (m: Array<string>): RequestParam => {
      return {
        fromCurrency: m[1],
        toCurrency: m[2],
        value: Number.parseFloat(m[3]),
      };
    },
    authenticate: (_) => true,
    handle: getConversion,
  },
];
