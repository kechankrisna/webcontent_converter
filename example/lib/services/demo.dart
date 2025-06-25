class Demo {
  static String getInvoiceContent() {
    return """
<html lang="en"><head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans&family=Noto+Serif+Khmer:wght@100;200;300&display=swap');
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans&family=Noto+Serif+Khmer:wght@100;200;300;500;600&display=swap');

@page {
    footer: page-footer;
    margin: auto;
    margin-top: 35pt;
    margin-bottom: 50pt;
    margin-footer: 18pt;
}

@page :first {
    margin-top: 0;
}

*,
html {
    padding: 0;
    margin: 0;
    font-family: 'Noto Serif Khmer', 'Noto Sans', sans-serif !important;
}

* {
    -webkit-print-color-adjust: true;
    -webkit-print-color-adjust: exact;
}

body,
p {
    margin: 0px;
    padding: 0px;
    font-family: 'Noto Serif Khmer', 'Noto Sans', sans-serif;
}

body {
    background: white;
}

p {
    line-height: 22px;
}

.invoice {
    /*max-width: 794px;*/
    margin: auto;
}

.container {
    padding: 5px 15px;
}

hr {
    border-top: 1px dashed silver;
}

.text-center {
    text-align: center;
}

.text-left {
    text-align: left;
}

.text-right {
    text-align: right;
}

.text-justify {
    text-align: justify;
}

.text-start {
    text-align: start;
}

.text-end {
    text-align: end;
}

.right {
    float: right;
}

.left {
    float: left;
}

.total {
    font-size: 1.5em;
    margin: 5px;
}

a {
    color: #1976d2;
}

span {
    color: #3a3a3a;
}

.full-width {
    width: 100%;
}

.width-100 {
    width: 100px;
}

.width-200 {
    width: 200px;
}

.width-300 {
    width: 300px;
}

.width-400 {
    width: 400px;
}

.inline-block {
    display: inline-block;
}

.flex {
    display: flex;
}

.half {
    width: 50%;
}

.padding_left {
    padding-left: 15px;
}

.padding_right {
    padding-right: 15px;
}

td {
    border: 1px solid silver;
    padding: 8px;
    border-collapse: collapse;
}

thead td {
    background: #4BAF4F;
    /* #1565c0; */
    color: white;
}

thead td,
tfoot td {
    font-weight: bold;
}


.logo {
    width: 55px;
    height: 55px;
    background-position: center;
    /* Center the image */
    background-repeat: no-repeat;
    /* Do not repeat the image */
    background-size: cover;
}

.logo img {
    width: 100%;
}

header,
footer {
    margin: auto;
    /*position: absolute;*/
    /*transform: translate3d(0,0,0);*/
}

footer {
    bottom: 10px;
}

@media print {
    footer {
        bottom: 10px;
    }
}

.page-break {
    page-break-after: always;
}

.capitalize {
    text-transform: capitalize;
}

.flex{display:flex;}
.col-1{flex:1;}
.col-2{flex:2;}
.col-3{flex:3;}
.col-4{flex:4;}
.col-5{flex:5;}
.col-6{flex:6;}
.col-7{flex:7;}
.col-8{flex:8;}
.col-9{flex:9;}
.col-10{flex:10;}
.col-11{flex:11;}
.col-12{flex:12;}

.hr{
  height: 2px;
  margin: 10px 0;
  border-top: 2px dashed #000000;
}

.divider {
  height: 2px;
  margin: 10px 0;
  border-top: 2px dashed #000000;
}

.KHQR_WRAPPER {
    width: 216px;
    display: grid;
}

.KHQR_SCAN_TEXT {
    width: 100%;
    height: 12px;
    background-image: url("data:img/png;base64,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");
    background-repeat: no-repeat;
    background-position: center;
    background-size: contain;
}

.KHQR_USD {
    width: 100%;
    height: 211px;
    background-image: url("data:img/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVAAAAGmCAYAAAAqI9zdAAARuklEQVR4nO3d3W4c53nA8RlFLdK6qJdJCgRBXC7d85o22mORvgHRN2CRV0DqBkyyF1BSN1BSvQFJN2BKPi1gsT4tIpI9KFIg1bJBP5yg9hQvo6GXy/2ah7vkzs7vBzyxKX7Njpi/35nZHeZFUWTTdHp62n758uXK8fHx8tnZ2WJ6+/z8vJX+OdVvDDRGu90+bbVa5+mfH3300T8vLy8fp0lvT3UfpIBOeo6OjlY2Nzf32+32SfoWxhhzF5MatL6+fpCaNI3WTewLdTqd1s7Oznar1er4YTHGzNosLS29OTw8fHRyctKemYAKpzGmTrOwsPA2NWsSIb3RJ+/v728KpzGmjlOuSG89oKncKysrR35wjDF1nxTS6GrUqtMY0/hJh/V7e3tbUw3o1tbWXtN3tDFmPifP8+/TudGpBDQ9FcAPjjFm3mdjY+MfJhrQ5eXl135wjDFNmdXV1S8nElArT2NME2eclejQd6bzAX54jDFNncePH/99KKDparsfHGNMkyddWBp2db7vH6bnRHmqkjHG/OEpToOeJ9o3oG4CYowxP8ygi0rX/uDg4GDdjjPGmB9m0KH8tUN3q09jjLk+6VA+3Typu5n3uu8N+uTJk003Oga4rtPpLOzv7291v+PyjvQpnB9//PHrdLd4+w7guoWFhc6bN28+THe/T++8XIGmX7shngCD9a5CL1egS0tLJw7fAYZLq9C3b9/+JCtXoGn1KZ4Ao6Uj9dTMrAzo4eHhuv0GMFpRFPmLFy8eZuUhvMN3gPGlZqaLSXl67md6w74DGE+e50UK6P3j4+Nl+2z+tdtXDzBOT0/Hesy9n3d+fn4xpVardTGD3l/l64/63N5tqWrcxzxqe6s+RubTxXnQ7e3tHa86mP/p1W63Rz7mvb29K5/V6XSK5eXlKx+zs7Nz5WPS2+Puz7QN3Y6Ojvp+3Obm5sX3noSDg4Oi1WqNvY0rKyvF/v5+cXJycu27p+1N7xtnX5r5m4tfcbS2tvbMX66A9k4Kzah4ZrcQ0O3t7YmEs9uzZ8/G2ra0PeNK+0tImzWpnfdcPKLXwcFB+k0El3+aDn0//vjj7Pj4+Nb3Vfd2TMra2tqV0w69Njc3s9evX2crKyuVtvPo6OjGpxmoj7Ozs8X7Xn1Et37xXF1dncj5w4jeIL18+TJ7+vRppa/08OHDi2h2SwHtdx5ze3s7/SaGa3+evu+rV68u98Py8vLF1+3evvTvKbxpf93Ff2y4XWU7G78Ub8KMcwjfe9iezvuNOiyd9iF81UPvQdN7ON7vcaXznb3S5w3bB2tra9fOj6a3q5xnNfWcdIu7e/6jRTaDK89+0gowapxVa9oH3XZ3d0fug+fPn187vZFWomkly/wTUGoRz+zd05y6pcPwFKt+M+wcZz/p8Xcfjh8eHvY9lB+0Xb37a2trq/I2UD8C2mDp/+DPnj2rRTx7pdidnJwMnHQusopHjx5d+ei0+qwiRXRjY+PKZ6SIMt8EtKFSPNNV4+6LK3WJZ/YuoMNWeOWqdBzp63RfcU+rz8g+SBeaulfJDx48qPw1qJf7/r6aKa08uwMzqXimpwD1ruZmXbqi3i2FMOrFixeXj7/36zJ/BLSheldnT548mcjKs/elnXV0dnYW3up0+qAOK3gmwyF8Q/VekNnb26vdynEWpXOnS0tLl8N8swJtqM8+++zi6nvvlee0+rrJIWx6ulD6OuMoL2JBXQloQ5XnPHtffpiCdpNX0qSvO26AveyRuhPQBusX0fLq/Ky/HDFtW9r+24xwuiiULpL1bkc6f0wzCWjD1TWi6RzubZ9jTPsineLofZVR2l9VnzfKfHARib5PYSojOktPxbnJ1f10WmESV8fTq5N6nzCf/sxLN5tJQLkwKKK9zxe9S+nwObotk3yRQLpIJqJkDuHp1u9wPv2zPJy/6+c3ltuSDqXH/ZUa3ecoux/fTZXPNOi+AUmKaPqPzuPHj6fx8JlRbqfldnZXJr2v3y3a+n3OtG9nV+Wu8IOku9r3ft/u2831bke6rd24j2F9ff3ad023BWz6z1sTxu3s6Kvf4W65+rvtw/m0mrvpyjetDNMLBUrp63WvYNPb0Svp/Q7n081Zem+Nx3xyCN8QVSNURjSdA+2+eJOCkW5AUgao0+lc+drp7arfp9TvsDwdgqftSHc2ev/998N/WekxpO1O9+/sJ3399L0ir8YqD+e7z4Gmm5OkcI97SzzqKX+31AaggvS74R3CAwQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgTdH/VpRVHkdi4wS/I8L2Zhc6xAgdqZlYWdgAK1NAsRFVCgtu46ogIK1NpdRlRAgdq7q4gKKDAX7iKiAgrMjduOqIACc+U2IyqgwNy5rYgKKDCXUkRbrdZUH5qAAnOr0+lMNaICCsy1aUZUQIG5N62ICijQCCmi7XZ7og9VQIHGODk5mWhEBRRolElGVECBxplURAUUaKRJRFRAgca6aUQFFGi0m0RUQIHGi0ZUQAHeRXR5ebnSrhBQgHdev35dKaICCtClSkQFFKDHuBFNNx0thn3ArPwCe4Dbluf5wD6m91mBAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAMnG7u7sf2Ks0gYACBAkoQJCAMg3f2as0gYAyDQJKIwgo0/A7e5UmEFCm4ff2Kk2QZ1lWDHucRVHkfhKAJsrzfGAf0/usQAGCBBQgSEABggQUIEhAAYIEFCBIQAGC5i6gh4eHPz88PFy86dfZ3d1d3NjYWJjMVjXb4eHhL5q+D5hPnkgPMIAn0gNMiYACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCA3oI8zxfzPP/l3D9QaBgBvQVFUZxlWfYnc/9AoWG8Fh5gAK+FB5gSAQUIElCAIAG9I3meL+V5/kEjHzzMCQG9I0VRnGRZdr+RDx7mhKvwAAO4Cg8wJY07hNzd3f3g3cq738r6+yzLvsuy7Ns029vb/3MHmwjUhEN4gAEcwgNMiYACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKECQgAIECShAkIACBAkoQJCAAgQJKEDQ/SbuuDzPf5xl2Z9lWfaj9GZRFL+egc0CaibPsqwYtslFUeT+UoEmyvN8YB/T+xzCAwQJKECQgAIECShAkIACBAkocCHP8wV7ohoBBUp/ZE9UI6BA6U/tiWoEFCh50UxFAgoQJKBAaejLurlOQIGSgFYkoEDp/+yJagQUKP3enqhGQIHS7+yJagR0Bi0tLS02fR9w+4qi+K3dXo0bKgMX8jx/ryiK/7Y3fuCGysC4vBKpIgEFSn9sT1QjoECpkb9k8iacAwUYwDlQgCkRUIAgAQUIElCAIAEFCBJQgCABBQgSUIAgAQUIElCAIAEFCBJQgCABBQiqQ0B/OgPbAHBNHQL6H1mWtWdgOwCuqMsh/LdZln04A9sBcKkuAf31qBs/A9y2Ol1E+t8Z2AaAS36lB8AAfqUHwJQIKECQgAIX8jz3e+ErElCg9GN7ohoBBUrv2RPVCChQum9PVCOg0FBra2tXDtlXVlZ+5Gehmjo+DzS9Lv50BrYD5s1ilmVn/lZ/MI/PA/XEfmAmOIQHCBJQgKA6BtRdmWA6vrdfq6ljQF1AonZOT09/WYNt/m4GtqFW3I0JKP303W+A4B13YwLG9a09VY2AAiUBrUhAgZK7MVUkoEDJr82pSEABggQUIEhAAYIEFCBIQAGCBBQgSEABggQUIEhAAYIEFCBIQAGCBBQgSEABggQUIEhAAYIEFCBIQAGCBBQgSEABggQUIEhAAYIEFCBIQAGCBBQgSEABggQUIEhAAYIEFCBIQAGCBBQgSEABggQUbsHp6emS/Tx/BBRux7/Zz/Mnz7KsGPaoiqLIm76TgGbK83xgH9P7rEDh9v1llmU/t9/rT0Dh9v3rqCM/6kFA4W78+/Hx8Xv2fb05Bzp/fuGCRe38LMuy97Ms+88sy37T9J0xS5wDbZ7/avoOqKEUzV81fSfUkRUowABWoABTIqAAQXcd0D/Psuyv7ngbAELu3/Fu+63nwwF15SISwAAuIt2CPM9/NvcPErhGQCeg3W7X/jEA1TX1EP4nWZa9nYHtAGbYqEN450ABBnAOFGBKBBQgSEABgu76ifTMiNXV1aXy5+Ho6Ohf/L3AaC4icUWe50vr6+v3Dg4O3F6NxnMVHiDIVXiAKRFQgCABBQgSUIAgAQUIElCAIAEFCBJQgCABBQgSUIAgAQUIElBqYWNj4y/8TTFrBJS6aPmbYta4GxPAAO7GBDAlAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBtQ7o7u7u0u7u7t/MwKYADZRnWVYMe9hFUeSzvFvyPP/boij+aQY2BZgzeZ4P7GN63zwcwv9mBrYBaKDar0ABpqUJK1CAOyGgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQQIKECSgAEECChAkoABBAgoQJKAAQffa7fapnQdQTWrnvVardW6/AVST2mkFChCwuLh4di/9j50HUM3y8vLxvfQ/wz5rYWGhsF+BpllaWhrYvjzPi9TO/OTkpL20tHQybN8URZH76QGaJEVy0MNN73vz5s2HF+dAnQcF+MGjR4+GHnmX3bx4HujDhw9fDPtgh/FAk3z11VdDH+3KysrLrHwi/dra2vNhH3x+7plOQHOcng4+KE+H759//vk/Xvx7UfxhcbmwsNA5Pz9vDfqkVquVdTod50KBuZYuHg0LaLpmlM5/Zt0v5dzc3HwybKdYhQJNMGr1ubOzs3P5drkCTavPVNZhq9DMFXlgjg278p69O1L/+uuvPykvvF+uQNPLkkatQrMRz40CqKtRbUtxTY3sftbSlbsxbW1t7afCDvsiaXm7sbEhosDcWFtbG3reM3v31KVHjx497f6zKwFNq9Avvvji70btlMPDw2x3d1dEgdrb2dkpXrwY+kzOy3Of154zn86B9s7q6uqX6V2jJn3jfp9vjDF1mO3t7ZGdS/Phhx/+qt/jubyI1O309LT9ySeffN3pdBZG/ddlbW0te/bsmQtLQK2sr68XT58+HbnJvReOuvW9I336wHEO5ZPnz5+7sATUSmrWOPFMh+7b29u7A1/uPmyZvbW1tTfO8rYchy3GmFmfcXuW5/n3Ozs728Mez8gHu76+flAlou12W0iNMTM16Vxnq9Uau2Mpnql9ox5D33OgvT799NMvj46OVqss0dvtdnrBfXZwcOD8KHBn0s2QqrySMh22p5uFfPnll5+O/NhxAppsbGwcHB4erkd2QorpycmJkAK3omo0Syme6bmeBwcHG2N9QpVl9vb29k5a2lY5pDfGmDpMalu67lOliZXPU+zt7W0tLCy89UNhjJmXSU3b39/frNrD0Ined78G5I3VqDGmzpMall44lJoWaeGNrpQdHBysp5D6ITLG1GlSOKOrzokFtFyNpnOjaWOsSI0xszxlONPzOzudTuum/btxQLtDWq5IhdQYM0sz6XCWM/bTmKp4+fLlytOnTx+9evXqQXpd/bur/Z7GBNyK8sbI6SWY6Zdmpil/EdwkTSWg3VJAj4+Pl9N88803f53eTne9L8MKcFMplOl2nOmfi4uLZ8vLy8cPHjx4NdVf2Z5l2f8D1uIOKArtUrUAAAAASUVORK5CYII=");
    background-repeat: no-repeat;
    background-position: center;
    background-size: contain;
    position: relative;
}

.KHQR_QRCODE {
    width: 100%;
    display: block;
    bottom: 12px;
    position: absolute;
}

.KHQR_QRCODE img {
    width: 150px;
    display: block;
    margin-left: auto;
    margin-right: auto;
}

.KHQR_BANK {
    width: 100%;
    height: 15px;
    background-image: url("data:img/png;base64,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");
    background-repeat: no-repeat;
    background-position: center;
    background-size: contain;
}

.spacer {
    height: 8px;
}


.payway_qr{
  min-width: 150px;
  min-height: 150px;
  max-width: 250px;
  max-height: 250px;
  padding: 10px;
  margin:auto;
}

/*
* bootstrap
*/

.col-xs-1,
.col-sm-1,
.col-md-1,
.col-lg-1,
.col-xs-2,
.col-sm-2,
.col-md-2,
.col-lg-2,
.col-xs-3,
.col-sm-3,
.col-md-3,
.col-lg-3,
.col-xs-4,
.col-sm-4,
.col-md-4,
.col-lg-4,
.col-xs-5,
.col-sm-5,
.col-md-5,
.col-lg-5,
.col-xs-6,
.col-sm-6,
.col-md-6,
.col-lg-6,
.col-xs-7,
.col-sm-7,
.col-md-7,
.col-lg-7,
.col-xs-8,
.col-sm-8,
.col-md-8,
.col-lg-8,
.col-xs-9,
.col-sm-9,
.col-md-9,
.col-lg-9,
.col-xs-10,
.col-sm-10,
.col-md-10,
.col-lg-10,
.col-xs-11,
.col-sm-11,
.col-md-11,
.col-lg-11,
.col-xs-12,
.col-sm-12,
.col-md-12,
.col-lg-12 {
    position: relative;
    min-height: 1px;
    padding-right: 15px;
    padding-left: 15px;
}

.col-xs-1,
.col-xs-2,
.col-xs-3,
.col-xs-4,
.col-xs-5,
.col-xs-6,
.col-xs-7,
.col-xs-8,
.col-xs-9,
.col-xs-10,
.col-xs-11,
.col-xs-12 {
    float: left;
}

.col-xs-12 {
    width: 100%;
}

.col-xs-11 {
    width: 91.66666667%;
}

.col-xs-10 {
    width: 83.33333333%;
}

.col-xs-9 {
    width: 75%;
}

.col-xs-8 {
    width: 66.66666667%;
}

.col-xs-7 {
    width: 58.33333333%;
}

.col-xs-6 {
    width: 50%;
}

.col-xs-5 {
    width: 41.66666667%;
}

.col-xs-4 {
    width: 33.33333333%;
}

.col-xs-3 {
    width: 25%;
}

.col-xs-2 {
    width: 16.66666667%;
}

.col-xs-1 {
    width: 8.33333333%;
}

.col-xs-pull-12 {
    right: 100%;
}

.col-xs-pull-11 {
    right: 91.66666667%;
}

.col-xs-pull-10 {
    right: 83.33333333%;
}

.col-xs-pull-9 {
    right: 75%;
}

.col-xs-pull-8 {
    right: 66.66666667%;
}

.col-xs-pull-7 {
    right: 58.33333333%;
}

.col-xs-pull-6 {
    right: 50%;
}

.col-xs-pull-5 {
    right: 41.66666667%;
}

.col-xs-pull-4 {
    right: 33.33333333%;
}

.col-xs-pull-3 {
    right: 25%;
}

.col-xs-pull-2 {
    right: 16.66666667%;
}

.col-xs-pull-1 {
    right: 8.33333333%;
}

.col-xs-pull-0 {
    right: auto;
}

.col-xs-push-12 {
    left: 100%;
}

.col-xs-push-11 {
    left: 91.66666667%;
}

.col-xs-push-10 {
    left: 83.33333333%;
}

.col-xs-push-9 {
    left: 75%;
}

.col-xs-push-8 {
    left: 66.66666667%;
}

.col-xs-push-7 {
    left: 58.33333333%;
}

.col-xs-push-6 {
    left: 50%;
}

.col-xs-push-5 {
    left: 41.66666667%;
}

.col-xs-push-4 {
    left: 33.33333333%;
}

.col-xs-push-3 {
    left: 25%;
}

.col-xs-push-2 {
    left: 16.66666667%;
}

.col-xs-push-1 {
    left: 8.33333333%;
}

.col-xs-push-0 {
    left: auto;
}

.col-xs-offset-12 {
    margin-left: 100%;
}

.col-xs-offset-11 {
    margin-left: 91.66666667%;
}

.col-xs-offset-10 {
    margin-left: 83.33333333%;
}

.col-xs-offset-9 {
    margin-left: 75%;
}

.col-xs-offset-8 {
    margin-left: 66.66666667%;
}

.col-xs-offset-7 {
    margin-left: 58.33333333%;
}

.col-xs-offset-6 {
    margin-left: 50%;
}

.col-xs-offset-5 {
    margin-left: 41.66666667%;
}

.col-xs-offset-4 {
    margin-left: 33.33333333%;
}

.col-xs-offset-3 {
    margin-left: 25%;
}

.col-xs-offset-2 {
    margin-left: 16.66666667%;
}

.col-xs-offset-1 {
    margin-left: 8.33333333%;
}

.col-xs-offset-0 {
    margin-left: 0;
}

@media (min-width: 768px) {
    .col-sm-1,
    .col-sm-2,
    .col-sm-3,
    .col-sm-4,
    .col-sm-5,
    .col-sm-6,
    .col-sm-7,
    .col-sm-8,
    .col-sm-9,
    .col-sm-10,
    .col-sm-11,
    .col-sm-12 {
        float: left;
    }
    .col-sm-12 {
        width: 100%;
    }
    .col-sm-11 {
        width: 91.66666667%;
    }
    .col-sm-10 {
        width: 83.33333333%;
    }
    .col-sm-9 {
        width: 75%;
    }
    .col-sm-8 {
        width: 66.66666667%;
    }
    .col-sm-7 {
        width: 58.33333333%;
    }
    .col-sm-6 {
        width: 50%;
    }
    .col-sm-5 {
        width: 41.66666667%;
    }
    .col-sm-4 {
        width: 33.33333333%;
    }
    .col-sm-3 {
        width: 25%;
    }
    .col-sm-2 {
        width: 16.66666667%;
    }
    .col-sm-1 {
        width: 8.33333333%;
    }
    .col-sm-pull-12 {
        right: 100%;
    }
    .col-sm-pull-11 {
        right: 91.66666667%;
    }
    .col-sm-pull-10 {
        right: 83.33333333%;
    }
    .col-sm-pull-9 {
        right: 75%;
    }
    .col-sm-pull-8 {
        right: 66.66666667%;
    }
    .col-sm-pull-7 {
        right: 58.33333333%;
    }
    .col-sm-pull-6 {
        right: 50%;
    }
    .col-sm-pull-5 {
        right: 41.66666667%;
    }
    .col-sm-pull-4 {
        right: 33.33333333%;
    }
    .col-sm-pull-3 {
        right: 25%;
    }
    .col-sm-pull-2 {
        right: 16.66666667%;
    }
    .col-sm-pull-1 {
        right: 8.33333333%;
    }
    .col-sm-pull-0 {
        right: auto;
    }
    .col-sm-push-12 {
        left: 100%;
    }
    .col-sm-push-11 {
        left: 91.66666667%;
    }
    .col-sm-push-10 {
        left: 83.33333333%;
    }
    .col-sm-push-9 {
        left: 75%;
    }
    .col-sm-push-8 {
        left: 66.66666667%;
    }
    .col-sm-push-7 {
        left: 58.33333333%;
    }
    .col-sm-push-6 {
        left: 50%;
    }
    .col-sm-push-5 {
        left: 41.66666667%;
    }
    .col-sm-push-4 {
        left: 33.33333333%;
    }
    .col-sm-push-3 {
        left: 25%;
    }
    .col-sm-push-2 {
        left: 16.66666667%;
    }
    .col-sm-push-1 {
        left: 8.33333333%;
    }
    .col-sm-push-0 {
        left: auto;
    }
    .col-sm-offset-12 {
        margin-left: 100%;
    }
    .col-sm-offset-11 {
        margin-left: 91.66666667%;
    }
    .col-sm-offset-10 {
        margin-left: 83.33333333%;
    }
    .col-sm-offset-9 {
        margin-left: 75%;
    }
    .col-sm-offset-8 {
        margin-left: 66.66666667%;
    }
    .col-sm-offset-7 {
        margin-left: 58.33333333%;
    }
    .col-sm-offset-6 {
        margin-left: 50%;
    }
    .col-sm-offset-5 {
        margin-left: 41.66666667%;
    }
    .col-sm-offset-4 {
        margin-left: 33.33333333%;
    }
    .col-sm-offset-3 {
        margin-left: 25%;
    }
    .col-sm-offset-2 {
        margin-left: 16.66666667%;
    }
    .col-sm-offset-1 {
        margin-left: 8.33333333%;
    }
    .col-sm-offset-0 {
        margin-left: 0;
    }
}

@media (min-width: 992px) {
    .col-md-1,
    .col-md-2,
    .col-md-3,
    .col-md-4,
    .col-md-5,
    .col-md-6,
    .col-md-7,
    .col-md-8,
    .col-md-9,
    .col-md-10,
    .col-md-11,
    .col-md-12 {
        float: left;
    }
    .col-md-12 {
        width: 100%;
    }
    .col-md-11 {
        width: 91.66666667%;
    }
    .col-md-10 {
        width: 83.33333333%;
    }
    .col-md-9 {
        width: 75%;
    }
    .col-md-8 {
        width: 66.66666667%;
    }
    .col-md-7 {
        width: 58.33333333%;
    }
    .col-md-6 {
        width: 50%;
    }
    .col-md-5 {
        width: 41.66666667%;
    }
    .col-md-4 {
        width: 33.33333333%;
    }
    .col-md-3 {
        width: 25%;
    }
    .col-md-2 {
        width: 16.66666667%;
    }
    .col-md-1 {
        width: 8.33333333%;
    }
    .col-md-pull-12 {
        right: 100%;
    }
    .col-md-pull-11 {
        right: 91.66666667%;
    }
    .col-md-pull-10 {
        right: 83.33333333%;
    }
    .col-md-pull-9 {
        right: 75%;
    }
    .col-md-pull-8 {
        right: 66.66666667%;
    }
    .col-md-pull-7 {
        right: 58.33333333%;
    }
    .col-md-pull-6 {
        right: 50%;
    }
    .col-md-pull-5 {
        right: 41.66666667%;
    }
    .col-md-pull-4 {
        right: 33.33333333%;
    }
    .col-md-pull-3 {
        right: 25%;
    }
    .col-md-pull-2 {
        right: 16.66666667%;
    }
    .col-md-pull-1 {
        right: 8.33333333%;
    }
    .col-md-pull-0 {
        right: auto;
    }
    .col-md-push-12 {
        left: 100%;
    }
    .col-md-push-11 {
        left: 91.66666667%;
    }
    .col-md-push-10 {
        left: 83.33333333%;
    }
    .col-md-push-9 {
        left: 75%;
    }
    .col-md-push-8 {
        left: 66.66666667%;
    }
    .col-md-push-7 {
        left: 58.33333333%;
    }
    .col-md-push-6 {
        left: 50%;
    }
    .col-md-push-5 {
        left: 41.66666667%;
    }
    .col-md-push-4 {
        left: 33.33333333%;
    }
    .col-md-push-3 {
        left: 25%;
    }
    .col-md-push-2 {
        left: 16.66666667%;
    }
    .col-md-push-1 {
        left: 8.33333333%;
    }
    .col-md-push-0 {
        left: auto;
    }
    .col-md-offset-12 {
        margin-left: 100%;
    }
    .col-md-offset-11 {
        margin-left: 91.66666667%;
    }
    .col-md-offset-10 {
        margin-left: 83.33333333%;
    }
    .col-md-offset-9 {
        margin-left: 75%;
    }
    .col-md-offset-8 {
        margin-left: 66.66666667%;
    }
    .col-md-offset-7 {
        margin-left: 58.33333333%;
    }
    .col-md-offset-6 {
        margin-left: 50%;
    }
    .col-md-offset-5 {
        margin-left: 41.66666667%;
    }
    .col-md-offset-4 {
        margin-left: 33.33333333%;
    }
    .col-md-offset-3 {
        margin-left: 25%;
    }
    .col-md-offset-2 {
        margin-left: 16.66666667%;
    }
    .col-md-offset-1 {
        margin-left: 8.33333333%;
    }
    .col-md-offset-0 {
        margin-left: 0;
    }
}

@media (min-width: 1200px) {
    .col-lg-1,
    .col-lg-2,
    .col-lg-3,
    .col-lg-4,
    .col-lg-5,
    .col-lg-6,
    .col-lg-7,
    .col-lg-8,
    .col-lg-9,
    .col-lg-10,
    .col-lg-11,
    .col-lg-12 {
        float: left;
    }
    .col-lg-12 {
        width: 100%;
    }
    .col-lg-11 {
        width: 91.66666667%;
    }
    .col-lg-10 {
        width: 83.33333333%;
    }
    .col-lg-9 {
        width: 75%;
    }
    .col-lg-8 {
        width: 66.66666667%;
    }
    .col-lg-7 {
        width: 58.33333333%;
    }
    .col-lg-6 {
        width: 50%;
    }
    .col-lg-5 {
        width: 41.66666667%;
    }
    .col-lg-4 {
        width: 33.33333333%;
    }
    .col-lg-3 {
        width: 25%;
    }
    .col-lg-2 {
        width: 16.66666667%;
    }
    .col-lg-1 {
        width: 8.33333333%;
    }
    .col-lg-pull-12 {
        right: 100%;
    }
    .col-lg-pull-11 {
        right: 91.66666667%;
    }
    .col-lg-pull-10 {
        right: 83.33333333%;
    }
    .col-lg-pull-9 {
        right: 75%;
    }
    .col-lg-pull-8 {
        right: 66.66666667%;
    }
    .col-lg-pull-7 {
        right: 58.33333333%;
    }
    .col-lg-pull-6 {
        right: 50%;
    }
    .col-lg-pull-5 {
        right: 41.66666667%;
    }
    .col-lg-pull-4 {
        right: 33.33333333%;
    }
    .col-lg-pull-3 {
        right: 25%;
    }
    .col-lg-pull-2 {
        right: 16.66666667%;
    }
    .col-lg-pull-1 {
        right: 8.33333333%;
    }
    .col-lg-pull-0 {
        right: auto;
    }
    .col-lg-push-12 {
        left: 100%;
    }
    .col-lg-push-11 {
        left: 91.66666667%;
    }
    .col-lg-push-10 {
        left: 83.33333333%;
    }
    .col-lg-push-9 {
        left: 75%;
    }
    .col-lg-push-8 {
        left: 66.66666667%;
    }
    .col-lg-push-7 {
        left: 58.33333333%;
    }
    .col-lg-push-6 {
        left: 50%;
    }
    .col-lg-push-5 {
        left: 41.66666667%;
    }
    .col-lg-push-4 {
        left: 33.33333333%;
    }
    .col-lg-push-3 {
        left: 25%;
    }
    .col-lg-push-2 {
        left: 16.66666667%;
    }
    .col-lg-push-1 {
        left: 8.33333333%;
    }
    .col-lg-push-0 {
        left: auto;
    }
    .col-lg-offset-12 {
        margin-left: 100%;
    }
    .col-lg-offset-11 {
        margin-left: 91.66666667%;
    }
    .col-lg-offset-10 {
        margin-left: 83.33333333%;
    }
    .col-lg-offset-9 {
        margin-left: 75%;
    }
    .col-lg-offset-8 {
        margin-left: 66.66666667%;
    }
    .col-lg-offset-7 {
        margin-left: 58.33333333%;
    }
    .col-lg-offset-6 {
        margin-left: 50%;
    }
    .col-lg-offset-5 {
        margin-left: 41.66666667%;
    }
    .col-lg-offset-4 {
        margin-left: 33.33333333%;
    }
    .col-lg-offset-3 {
        margin-left: 25%;
    }
    .col-lg-offset-2 {
        margin-left: 16.66666667%;
    }
    .col-lg-offset-1 {
        margin-left: 8.33333333%;
    }
    .col-lg-offset-0 {
        margin-left: 0;
    }
}

    * {
    -webkit-locale: auto;
    white-space: normal;
    }
    body, *{
        font-family: 'Noto Serif Khmer', 'Noto Sans', sans-serif !important;
    }
    @page {
      margin: 0;
      size: a4;
    }
</style></head>



<body>
    <div class="invoice">
        <div class="container">
            <div class="full-width inline-block">
                
                <!-- header part -->
                <div class="text-center">
                  <h1 style="padding-left:-15px;">
                     វិក័យប័ត្រ 
                  </h1>
                  <h1 style="padding-left:-15px;">
                     Invoice 
                  </h1>
                  <p></p>
                </div>
            </div>
            <hr>
            <!-- end header part -->

            <!-- information -->
            <div class="full-width inline-block">
                <div class="half left">
                    <div class="padding_right">
                        <p>ហាង / Store</p>
                        <p><b> ឈ្មោះ / Name </b>: multi store name </p>
                        <p><b> អាស័យដ្ឋាន / Address </b>: unknown</p>
                        <p><b> លេខទូរស័ព្ទ / Phone </b>: 010464144 </p>
                        <p><b> អុីម៉ែល / Email </b>: multi.store@mylekha.app </p>
                        <p><b> កាលបរិច្ឆេត&ZeroWidthSpace; / Date </b>: Saturday, 26/Apr/2025 08:54 </p>
                        <p><b> លេខវិក័យប័ត្រ / Invoice</b> : S3519-1000066 </p>
                        <p><b> លេខយោង / Reference </b>: ......................</p>
                    </div>

                </div>
                <div class="half right">
                    <div class="padding_right">
                        <p> អតិថិជន / Customer</p>
                        <p><b> ឈ្មោះ / Name </b>: Walk-In </p>
                        <p><b> អាស័យដ្ឋាន / Address </b>: ........................</p>
                        <p><b> លេខទូរស័ព្ទ / Phone </b>: 0718887569</p>
                        <p><b> អុីម៉ែល / Email </b>: ........................</p>
                        <p><b> ការទូទាត់ប្រាក់ / Payment </b>: completed </p>
                        
                        

                    </div>
                </div>
            </div>

            <p> កំនត់ចំនាំ / Note : </p>
            <hr>
            <!-- product part -->
            <table align="center" width="100%" cellpadding="0" cellspacing="0" role="presentation">
                <thead>
                    <tr>
                        <td align="center"> លរ.&ZeroWidthSpace; <br> No. </td>
                        <td align="center" class="width-300"> បរិយាយទំនិញ <br> Description </td>
                        <td align="center"> ចំនួន <br> Qty </td>
                        <td align="center"> តំលៃ &ZeroWidthSpace;<br> Price </td>
                        <td align="center"> បញ្ចុះថ្លៃ <br> Discount </td>
                        <td align="center">&ZeroWidthSpace; សរុប <br> Total </td>
                    </tr>
                </thead>
                <tbody>
                  
                    <tr>
                            <td align="center" valign="top">1</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ក្លិនដាក់ឡាន ក្លែត Glade Fresh Lemon( 180g)yellow</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000008 </p>
                                        
                                        
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre></pre><p></p>
                            </td>
                            <td align="center" valign="top">3.00</td>
                            <td align="center" valign="top">៛ 2.36</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 7.08</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">2</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ប្រេងលាបខ្លួនផ្លរ៉ាអាយរីស BODY OIL FLORAL Iris(300ml)</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000012 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ប្រេងលាបខ្លួនផ្លរ៉ាអាយរីស ខ្លិនផ្កា (ចំណុះ ៣០០មីលីលីត្រ)Body Oil Floral Iris (300ml 10.1 FL 0Z)</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ប្រេងលាបខ្លួនផ្លរ៉ាអាយរីស ខ្លិនផ្កា (ចំណុះ ៣០០មីលីលីត្រ)Body Oil Floral Iris (300ml 10.1 FL 0Z)</pre><p></p>
                            </td>
                            <td align="center" valign="top">3.00</td>
                            <td align="center" valign="top">៛ 10.00</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 30.00</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">3</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ក្លិនដាក់ឡាន ក្លែត Glade Fresh Lemon( 180g x 2)yellow</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000007 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ក្លិនក្រអូបហ្វេសក្លែត(ចំណុះសុទ្ធ ១៨០ក្រាម) Glade Fresh Lemon (180 g)</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ក្លិនក្រអូបហ្វេសក្លែត(ចំណុះសុទ្ធ ១៨០ក្រាម) Glade Fresh Lemon (180 g)</pre><p></p>
                            </td>
                            <td align="center" valign="top">2.00</td>
                            <td align="center" valign="top">៛ 4.72</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 9.44</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">4</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ឡេលាបអាហ្វាស្រ៊ី Apha3Plus+ ARBUTIN (500ml)</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000011 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>អាហ្វាស្រ៊ីផ្លាស់ អាពូទីន ខូលេជេក យូវីប្រូថិកសិន SPF50 ស៊ីជុំពូ (ចំណុះ ៥០០មីលីលីត្រ )ALPHA 3Plus+ ARBUTIN Collagen Whitening LOTION UV Protection (Pink ,500 ml)</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>អាហ្វាស្រ៊ីផ្លាស់ អាពូទីន ខូលេជេក យូវីប្រូថិកសិន SPF50 ស៊ីជុំពូ (ចំណុះ ៥០០មីលីលីត្រ )ALPHA 3Plus+ ARBUTIN Collagen Whitening LOTION UV Protection (Pink ,500 ml)</pre><p></p>
                            </td>
                            <td align="center" valign="top">1.00</td>
                            <td align="center" valign="top">៛ 10.00</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 10.00</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">5</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ក្រេមផាត់ថ្ពាល់ ភិងភិចជី SIVANNA PINK PIGGY (5g) PINK</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000022 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ក្រេមផាត់ថ្ពាល ស៊ីវាន់ណា ភិងភិកជី លេខ០១(ចំណុះ ៥ក្រាម) SIVANNA PINK PIGGY Blush No.01 (5g ) Pink</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ក្រេមផាត់ថ្ពាល ស៊ីវាន់ណា ភិងភិកជី លេខ០១(ចំណុះ ៥ក្រាម) SIVANNA PINK PIGGY Blush No.01 (5g ) Pink</pre><p></p>
                            </td>
                            <td align="center" valign="top">1.00</td>
                            <td align="center" valign="top">៛ 2.50</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 2.50</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">6</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ប្រេងលាបខ្លួនផ្កាកូលាប (៣០០មល)   BODY OID ENGLISH ROSE( 300ml)</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000015 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ប្រេងលាបខ្លួនអ៊ិងលីស រូស ខ្លិនផ្កា (ចំណុះ ៣០០មីលីលីត្រ)Body Oil English Rose (300ml 10.1 FL 0Z)</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ប្រេងលាបខ្លួនអ៊ិងលីស រូស ខ្លិនផ្កា (ចំណុះ ៣០០មីលីលីត្រ)Body Oil English Rose (300ml 10.1 FL 0Z)</pre><p></p>
                            </td>
                            <td align="center" valign="top">1.00</td>
                            <td align="center" valign="top">៛ 8.50</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 8.50</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">7</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ក្រេមផាត់ថ្ពាល GLOW LOGRAM CHARMISS(4g)PINK</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000020 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ក្រេមផាត់ថ្ពាល ពណ៌ស៊ីជុំពូ(ចំណុះ ៤ក្រាម) Glow logram Charmiss (4g ) Pink</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ក្រេមផាត់ថ្ពាល ពណ៌ស៊ីជុំពូ(ចំណុះ ៤ក្រាម) Glow logram Charmiss (4g ) Pink</pre><p></p>
                            </td>
                            <td align="center" valign="top">1.00</td>
                            <td align="center" valign="top">៛ 2.50</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 2.50</td>
                        </tr>
                  
                    <tr>
                            <td align="center" valign="top">8</td>
                            <td align="left">
                                <div class="full-width inline-block" style="clear:both">
                                    <div style="float:left;width:80%;">
                                        <p>ក្រេមលាបការពារបបូរមាត់ ក្លួស៊ី BABY BUBBLE GLOSSY GUMMY(5g.017.1 fl.oz)</p>
                                        <p> លេខSKU&ZeroWidthSpace;: S-1000019 </p>
                                        
                                        
                                        
                                          <div style="padding:10px;"><p>ក្រេមលាបការពារបបូរមាត់ បេប៊ីបាប់បល ក្លូស៊ីហ្កែមម៉ី ពណ៌ប្រាក់ (ចំណុះ ៥ក្រាម)BABY BUBBLE GLOSSY GUMMY (5g 0.17.1 FL 0Z.) Silver</p></div>
                                        
                                    </div>
                                        
                                </div>    
                                <p></p><pre>ក្រេមលាបការពារបបូរមាត់ បេប៊ីបាប់បល ក្លូស៊ីហ្កែមម៉ី ពណ៌ប្រាក់ (ចំណុះ ៥ក្រាម)BABY BUBBLE GLOSSY GUMMY (5g 0.17.1 FL 0Z.) Silver</pre><p></p>
                            </td>
                            <td align="center" valign="top">1.00</td>
                            <td align="center" valign="top">៛ 5.00</td>
                            <td align="center" valign="top">៛ 0.00</td>
                            <td align="center" valign="top">៛ 5.00</td>
                        </tr>
                    

                </tbody>

                <tbody>
                  
                  
                    
                      
                    

                    

                    
                    <tr>
                        <td colspan="5" align="right"> ថ្លៃសេវា / Service charge ( 10.00 % )</td>
                        <td rowspan="1" align="center">៛ 7.50</td>
                    </tr>
                    

                    
                    <tr>
                        <td colspan="5" align="right"> អាករលើតំលៃបន្ថែម / VAT( 10.00 % )</td>
                        <td rowspan="1" align="center">៛ 7.50</td>
                    </tr>
                    

                    <tr>
                        <td colspan="5" align="right"> សរុបថ្លៃ / Total price (Cambodian Riel) </td>
                        <td rowspan="1" align="center">៛ 90.02 </td>
                    </tr>
                    <tr>
                        <td colspan="5" align="right"> សរុបថ្លៃ / Total price (United States Dollar) </td>
                        <td rowspan="1" align="center">\$ 90.02 </td>
                    </tr>
                    
                    <tr>
                        <td colspan="5" align="right"> បង់ប្រាក់ / Paid </td>
                        <td rowspan="1" align="center">៛ 90.02</td>
                    </tr>
                    <tr>
                        <td colspan="5" align="right"> នៅជំពាក់ / Due</td>
                        <td rowspan="1" align="center">៛ 0.00</td>
                    </tr>
                    
                </tbody>

            </table>

            

        </div>
        
        <div class="container">
            <p>Thank you for shopping with us. Please come again</p>
        </div>
    </div>
    <div class="invoice">
      <footer class="container full-width flex"> Published by MYLEKHA on Wednesday, 25/Jun/2025 12:58.</footer>
    </div>


</body></html>
   """;
  }

  static String getReceiptContent() {
    return """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RECEIPT</title>
</head>

<style>
    body,
    p {
        margin: 0px;
        padding: 0px;
    }
    
    body {
        background: #eee;
        width: 302.36px;
    }
    
    .receipt {
        max-width: 302.36px;
        margin: auto;
        background: white;
    }
    
    .container {
        padding: 5px 15px;
    }
    
    hr {
        border-top: 1px dashed black;
    }
    
    .text-center {
        text-align: center;
    }
    
    .text-left {
        text-align: left;
    }
    
    .text-right {
        text-align: left;
    }
    
    .text-justify {
        text-align: justify;
    }
    
    .right {
        float: right;
    }
    
    .left {
        float: left;
    }
    
    .total {
        font-size: 1.5em;
        margin: 5px;
    }
    
    a {
        color: #1976d2;
    }
    
    span {
        color: grey;
    }
    
    .full-width {
        width: 100%;
    }
    
    .inline-block {
        display: inline-block;
    }
</style>

<body>

    <div class="receipt">
        <div class="container">
            <!-- header part -->
            <div class="text-center">
                <p>MYLEKHA STORE</p>
                <hr>
                <p class="total">320.00</p>
                <span>Total</span>
            </div>
            <hr>
            <!-- end header part -->

            <p>Cashier: owner</p>
            <p>POS: POS 1</p>
            <hr>
            <!-- product part -->
            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>

            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>
            <hr>
            <!-- end product part -->

            <!-- footer part -->
            <p class="full-width inline-block">
                <b class="left">Total</b>
                <b class="right">4.00</b>
            </p>
            <p class="full-width inline-block">
                <b class="left">Cash</b>
                <b class="right">4.00</b>
            </p>
        </div>
        <hr>
        <!-- end footer part -->
        <div class="container">
            <p class="full-width inline-block">
                <span class="left">01/09/2020 22:23</span>
                <span class="right">No 3-10001</span>
            </p>
        </div>

    </div>
    <div class="container text-center">
        <br>
        <p>@2020 <a href="https://mylekha.app">MYLEKHA</a>. All right reserved.</p>
    </div>


</body>

</html>
  """;
  }

  static String getShortReceiptContent() {
    return """
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RECEIPT</title>
</head>

<style>
    body,
    p {
        margin: 0px;
        padding: 0px;
    }
    
    body {
        background: #eee;
        width: 302.36px;
    }
    
    .receipt {
        max-width: 302.36px;
        margin: auto;
        background: white;
    }
    
    .container {
        padding: 5px 15px;
    }
    
    hr {
        border-top: 1px dashed black;
    }
    
    .text-center {
        text-align: center;
    }
    
    .text-left {
        text-align: left;
    }
    
    .text-right {
        text-align: left;
    }
    
    .text-justify {
        text-align: justify;
    }
    
    .right {
        float: right;
    }
    
    .left {
        float: left;
    }
    
    .total {
        font-size: 1.5em;
        margin: 5px;
    }
    
    a {
        color: #1976d2;
    }
    
    span {
        color: grey;
    }
    
    .full-width {
        width: 100%;
    }
    
    .inline-block {
        display: inline-block;
    }
</style>

<body>

    <div class="receipt">
        <div class="container">
            <!-- header part -->
            <div class="text-center">
                <p>MYLEKHA STORE</p>
                <hr>
                <p class="total">320.00</p>
                <span>Total</span>
            </div>
            <hr>
            <!-- end header part -->

            <p>Cashier: owner</p>
            <p>POS: POS 1</p>
            <hr>
            <!-- product part -->
            <p class="full-width inline-block">
                <b class="left">Item c1 p2</b>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>

            <p class="full-width inline-block">
                <strong class="left">Item c1 p2</strong>
                <b class="right">4.00</b>
            </p>
            <p><span>2 x 2.00</span></p>
            <p><span>+egg (0.60)</span></p>
            <p><span>+rice (3.00)</span></p>


            <hr>
            <!-- end product part -->

            <!-- footer part -->
            <p class="full-width inline-block">
                <b class="left">Total</b>
                <b class="right">4.00</b>
            </p>
            <p class="full-width inline-block">
                <b class="left">Cash</b>
                <b class="right">4.00</b>
            </p>
        </div>
        <hr>
        <!-- end footer part -->
        <div class="container">
            <p class="full-width inline-block">
                <span class="left">01/09/2020 22:23</span>
                <span class="right">No 3-10001</span>
            </p>
        </div>

    </div>
    <div class="container text-center">
        <br>
        <p>សូមអរគុណ</p>
        <p>@2020 <a href="https://mylekha.app">MYLEKHA</a>. All right reserved.</p>
    </div>


</body>

</html>  
  """;
  }
}
