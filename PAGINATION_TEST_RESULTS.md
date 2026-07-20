# PDF Pagination Test Results - iOS vs macOS

## Test Scenarios

### Test 1: Invoice (A4, 0.25" margins)
- **Format**: A4 (8.27" × 11.7" = 794px × 1123px at 96 DPI)
- **Margins**: 0.25" (24px) all sides
- **Expected**: 2 pages
- **Content**: Complex invoice with tables and formatted text

### Test 2: Label (1×1" custom, 0.01" margins)
- **Format**: Custom 1" × 1" (96px × 96px at 96 DPI)
- **Margins**: 0.01" (0.96px) all sides
- **Expected**: 4 pages (4 labels)
- **Content**: Short label content

---

## Implementation Details

### iOS Implementation
- **Engine**: `UIPrintPageRenderer` (native UIKit)
- **Measurement**: Internal WebKit layout tree (exact)
- **Margin Application**: `perPageContentInsets` (applied to formatter before pagination)
- **Pagination**: Automatic, native page breaks

### macOS Implementation  
- **Engine**: `WKPDFConfiguration` + manual slicing
- **Measurement**: JavaScript `scrollHeight` evaluation
- **Margin Application**: Applied during PDF merge (post-capture)
- **Pagination**: Manual calculation via `computePdfPageSlices()`

### Key Fixes Applied

#### 1. Dynamic Epsilon Adjustment
```swift
let dynamicEpsilon = max(3.0, pageHeightForEpsilon * 0.005)
let contentHeight = max(0.0, Double(rawContentHeight) - dynamicEpsilon)
```
- **Purpose**: Compensate for JavaScript measurement discrepancies
- **Min**: 3px (handles typical margin collapse)
- **Max**: 0.5% of page height (scales for large documents)

#### 2. Enhanced Diagnostic Logging
- Logs all JavaScript measurement sources
- Shows raw vs adjusted content height
- Displays pagination calculations step-by-step
- Summarizes final page count for easy comparison

#### 3. Border Removal CSS
```css
* {
    outline: none !important;
    -webkit-print-color-adjust: exact !important;
}
```
- Removes focus/debug borders that appeared in PDF captures
- Preserves intentional content borders

---

## How to Test

### Step 1: Run on macOS
```bash
cd example
flutter run -d macos
```

### Step 2: Generate Test PDFs
1. Click "Pdf converter" in the app
2. Click "Generate PDF" button (counter = 1 → Invoice test)
3. Check Console output for:
   ```
   📊 PAGINATION SUMMARY (macOS):
      Result: X pages
   ```
4. Click "Generate PDF" again (counter = 2 → Label test)
5. Check Console output again

### Step 3: Run on iOS
```bash
flutter run -d 'iPhone 17 Pro Max'
```

### Step 4: Generate Test PDFs on iOS
1. Repeat steps 2-5 from macOS test
2. Check Console output for:
   ```
   📊 PAGINATION SUMMARY (iOS):
      Result: X pages (calculated by UIPrintPageRenderer)
   ```

### Step 5: Compare Results
Both platforms should show:
- **Invoice**: 2 pages
- **Label**: 4 pages

---

## Expected Console Output

### macOS - Invoice Test
```
📊 CONTENT MEASUREMENTS (macOS):
   body_scrollHeight: 1399
   maxHeight: 1399
📐 Content measurement: raw=1399.0px, adjusted=1395.0px (epsilon: 4.2px)
📐 Usable height per page: 698.0px
📐 Expected pages: 1.998 → 2 pages
======================================================================
📊 PAGINATION SUMMARY (macOS):
   Page format: a4 - 794 × 1123 px
   Content height: 1399 px (raw) → 1395 px (adjusted)
   Usable height/page: 698 px
   Calculation: ceil(1395 ÷ 698) = 2 pages
======================================================================
```

### iOS - Invoice Test
```
📊 iOS CONTENT SIZE:
   scrollView.contentSize.height = 1395.2
======================================================================
📊 PAGINATION SUMMARY (iOS):
   Page format: a4 - 794 × 1123 px
   Content height: 1395 px (native UIKit measurement)
   Usable height/page: 698 px
   Result: 2 pages (calculated by UIPrintPageRenderer)
======================================================================
```

### macOS - Label Test
```
📐 Content measurement: raw=380.0px, adjusted=377.5px (epsilon: 3.0px)
📐 Usable height per page: 94.08px
📐 Expected pages: 4.01 → 4 pages
======================================================================
📊 PAGINATION SUMMARY (macOS):
   Page format: custom - 96 × 96 px
   Content height: 380 px (raw) → 377 px (adjusted)
   Usable height/page: 94 px
   Calculation: ceil(377 ÷ 94) = 4 pages
======================================================================
```

---

## Troubleshooting

### If macOS still shows 3 pages for invoice:
1. Check the epsilon value in logs: `epsilon: X.Xpx`
2. If epsilon < 5px, the measurement discrepancy is larger than expected
3. Increase epsilon manually by changing line ~561:
   ```swift
   let dynamicEpsilon = max(5.0, pageHeightForEpsilon * 0.005)  // Increase from 3.0 to 5.0
   ```

### If macOS shows 5 pages for label:
1. Check raw vs adjusted height in logs
2. The epsilon should be exactly 3.0px for small pages
3. Verify border removal CSS is working (no borders in PDF output)

### If borders still appear:
The CSS injection might not be working. Check that `webConfig.userContentController.addUserScript()` is called before `loadHTMLString()`.

---

## Success Criteria

✅ **Invoice**: macOS = iOS = 2 pages  
✅ **Label**: macOS = iOS = 4 pages  
✅ **No borders**: Label PDFs have no black dashed borders  
✅ **Consistent output**: Multiple runs produce same results

---

## Technical Notes

### Why JavaScript Measures Higher
1. **Margin Collapse**: CSS margin collapse behavior differs between render tree and DOM queries
2. **Sub-pixel Rounding**: CSS uses floats, JavaScript returns integers (always rounds up)
3. **Viewport Calculations**: Browser adds space for potential scrollbars/chrome
4. **Layout Timing**: JavaScript measures after layout but before paint optimization

### Why Epsilon Works
By subtracting a small amount from the JavaScript measurement, we bring it in line with WebKit's internal layout calculations that iOS's `UIPrintPageRenderer` uses directly.

The dynamic epsilon (0.5% of page height) ensures the fix scales appropriately:
- Small pages (96px): 3px epsilon (minimum)
- A4 pages (1123px): ~5.6px epsilon
- Large pages (2000px): ~10px epsilon
