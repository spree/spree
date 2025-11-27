# API Breaking Change: New Required Params - spree

# API Breaking Change: New Required Params

> **Problem Statement:** Users may experience failures with API calls due to new required parameters that were previously optional or missing.

## Applies To

- **Product/Repository:** spree
- **Language/Framework:** Not specific
- **Versions:** All versions affected
- **Environment:** Both Development and Production

## Symptoms

Users experiencing this issue may observe:

- **Error Messages:**
  ```json
  { "error": "missing_required_param", "message": "The 'category' parameter is required." }
  ```

- **Behavior:**
  - API calls that were previously successful may now return 400 Bad Request errors.
  - Relevant integrations may fail, impacting functionality.
  - Existing documentation may not reflect new requirements, leading to confusion.

- **Impact:**
  - Users might find their applications failing to interact with the API as expected, leading to service disruptions.

## Root Cause

### Technical Explanation

This issue occurs due to recent changes in the API’s expected parameters. Certain parameters that were previously optional have been made mandatory. This change enhances data integrity and provides clearer API responses.

**Key factors:**
- New parameter specifications introduced in the latest API version.
- Changes in the authentication process affecting session management, requiring stricter validation of request payloads.
- Enhancements to the interactive installer, altering configuration handling.

## Resolution

### Migration Guide (For Code-Level Changes)

**IMPORTANT:** This section provides guidance for adapting your API calls to accommodate the recent changes.

#### Before (Old Code/Config):
```json
{
  "name": "example_product",
  "price": 100
  // previous 'category' parameter was optional
}
```

#### After (New Code/Config):
```json
{
  "name": "example_product",
  "price": 100,
  "category": "example_category"  // 'category' parameter is now required
}
```

#### What Changed:
- The `category` field is now a required parameter.
- Authentication process now mandates additional tokens.
- The structure of API requests must align with the new expectations to avoid errors.

### Step-by-Step Fix

**Method 1: Update API Calls**

Follow these steps to resolve the issue:

1. **Identify Required Parameters**
   - Review the updated API documentation to identify all required parameters for your specific API calls.

2. **Update Your API Calls**
   - Adjust your existing code to include the new required parameters.
   ```json
   {
     "name": "updated_product",
     "price": 150,
     "category": "updated_category"
   }
   ```

3. **Test Your Integration**
   ```bash
   curl -X POST "https://api.yourservice.com/products" -H "Authorization: Bearer your_token" -d '{
     "name": "new_product",
     "price": 200,
     "category": "new_category"
   }'
   ```

**Expected Result:**
Upon making the change, the API should respond successfully, indicating that the new parameters are recognized and processed correctly. Monitor responses for confirmation of successful integration.

**Testing Considerations:**
- Validate that authentication tokens are properly formatted and included.
- Test in a staging environment before deploying changes to production.
- Consult API logs for any unusual error patterns not covered above.
```

### Additional Recommendations
- Provide clear examples of full API responses after the changes to help users verify success.
- Consider including a section on how to handle common errors if the parameter requirements are still not met.
- Encourage users to maintain a version history of their API integration codes for easy rollback if needed.