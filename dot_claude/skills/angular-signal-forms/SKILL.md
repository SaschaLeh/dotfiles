---
name: angular-signal-forms
description: Angular Signal Forms API (experimental, @angular/forms/signals). Covers form(), schema(), FormField directive, built-in validators (required, email, min, max, minLength, maxLength, pattern), custom validation with validate()/validateTree()/validateAsync()/validateHttp(), conditional logic (applyWhen, applyWhenValue), nested forms (apply, applyEach), form submission with submit(), debounce(), disabled/hidden/readonly fields, metadata system, Zod/Standard Schema integration via validateStandardSchema(), and FormValueControl/FormCheckboxControl contracts for custom controls.
---

# Angular Signal Forms

Experimental signal-based forms API available since Angular 21 (November 2025). Import path: `@angular/forms/signals`.

**Status:** `@experimental 21.0.0` - API may change between versions.

## Import Path

```typescript
import {
  form,
  schema,
  submit,
  FormField,
  required,
  email,
  min,
  max,
  minLength,
  maxLength,
  pattern,
  validate,
  validateTree,
  validateAsync,
  validateHttp,
  validateStandardSchema,
  apply,
  applyEach,
  applyWhen,
  applyWhenValue,
  debounce,
  disabled,
  hidden,
  readonly,
  metadata,
  createMetadataKey,
  createManagedMetadataKey,
  MetadataReducer,
  REQUIRED,
  MIN,
  MAX,
  MIN_LENGTH,
  MAX_LENGTH,
  PATTERN,
  requiredError,
  emailError,
  minError,
  maxError,
  minLengthError,
  maxLengthError,
  patternError,
  standardSchemaError,
  provideSignalFormsConfig,
  FORM_FIELD,
  type FieldTree,
  type FieldState,
  type SchemaPathTree,
  type ValidationError,
  type FormValueControl,
  type FormCheckboxControl,
} from "@angular/forms/signals";
```

## Core Concepts

### form() - Create a Form

`form()` wraps a `WritableSignal` model in a `FieldTree`. The model is the **single source of truth** - form mutations directly update the original signal.

```typescript
// Overloads:
form<TModel>(model: WritableSignal<TModel>): FieldTree<TModel>;
form<TModel>(model: WritableSignal<TModel>, schemaOrOptions: SchemaOrSchemaFn<TModel> | FormOptions): FieldTree<TModel>;
form<TModel>(model: WritableSignal<TModel>, schema: SchemaOrSchemaFn<TModel>, options: FormOptions): FieldTree<TModel>;
```

```typescript
import { Component, signal } from "@angular/core";
import { form, FormField, required, email } from "@angular/forms/signals";

@Component({
  selector: "app-login",
  imports: [FormField],
  template: `
    <input type="email" [formField]="loginForm.email" />
    <input type="password" [formField]="loginForm.password" />
  `,
})
export class LoginComponent {
  loginModel = signal({ email: "", password: "" });

  loginForm = form(this.loginModel, (path) => {
    required(path.email);
    email(path.email);
    required(path.password);
  });
}
```

**Critical behavior:** The form mutates the source signal directly.

```typescript
const model = signal({ name: "John" });
const f = form(model);
f.name().value.set("Jane");
model(); // { name: 'Jane' } - source signal was mutated!
```

### FieldTree - Nested Signal Structure

`form()` returns a `FieldTree` - a nested signal structure mirroring the model shape. Each property provides a `FieldState`:

```typescript
// Access field state
loginForm.email().value(); // Current value
loginForm.email().valid(); // No errors AND no pending validators
loginForm.email().invalid(); // Has errors (regardless of pending)
loginForm.email().errors(); // ValidationError.WithField[]
loginForm.email().errorSummary(); // Errors for field + all descendants
loginForm.email().dirty(); // Was modified
loginForm.email().touched(); // Was focused
loginForm.email().pending(); // Async validators running
loginForm.email().hidden(); // Is hidden
loginForm.email().disabled(); // Is disabled
loginForm.email().disabledReasons(); // DisabledReason[]
loginForm.email().readonly(); // Is readonly
loginForm.email().submitting(); // Submission in progress

// Mutation
loginForm.email().value.set("new@email.com");
loginForm.email().reset(); // Reset touched/dirty, optionally set value
loginForm.email().focusBoundControl(); // Focus first bound UI control

// Read metadata
loginForm.email().metadata(REQUIRED); // boolean | undefined
loginForm.email().metadata(MIN_LENGTH); // number | undefined
```

**Important:** `valid()` is NOT `!invalid()`. When async validators are pending, both can be `false`.

### schema() - Reusable Schema Definitions

```typescript
const addressSchema = schema<Address>((path) => {
  required(path.street);
  required(path.city);
  pattern(path.zipCode, /^\d{5}$/);
});

const userSchema = schema<User>((path) => {
  required(path.name);
  apply(path.address, addressSchema); // Compose schemas
});
```

**Critical:** The schema function runs once during form creation and is **non-reactive**. Use `LogicFn` for reactive behavior:

```typescript
// WRONG - condition is not reactive
form(model, (p) => {
  if (someSignal()) {
    // This won't react to signal changes
    required(p.field);
  }
});

// CORRECT - LogicFn inside is reactive
form(model, (p) => {
  required(p.field, {
    when: () => someSignal(), // This IS reactive
  });
});
```

## Validation

### Built-in Validators

All validators accept static values OR a `LogicFn` for dynamic constraints:

```typescript
required(path, config?)                    // config: { message?, when? }
email(path, config?)
minLength(path, length | LogicFn, config?)
maxLength(path, length | LogicFn, config?)
min(path, value | LogicFn, config?)
max(path, value | LogicFn, config?)
pattern(path, regex | LogicFn, config?)
```

```typescript
form(model, (path) => {
  required(path.email, { message: "E-Mail ist erforderlich" });
  email(path.email);
  minLength(path.password, 8);
  pattern(path.phone, /^\+49\d{10,11}$/);

  // Dynamic min based on another field
  min(path.age, ({ valueOf }) => (valueOf(path.requiresAdult) ? 18 : 0));
});
```

### Conditional Validation with `when`

The `when` option on `required()` enables conditional validation reactively:

```typescript
required(path.email, {
  when: ({ valueOf }) => valueOf(path.contactMethod) === "email",
});
```

### Custom Validators - validate()

For synchronous single-field validation:

```typescript
validate(path.city, (ctx) => {
  const allowed = ["Frankfurt", "Berlin", "München"];
  if (!allowed.includes(ctx.value())) {
    return {
      kind: "invalid-city",
      value: ctx.value(),
      allowed,
      message: "Ungültige Stadt",
    };
  }
  return undefined; // No error
});
```

### Cross-Field Validation - validateTree()

For validation that targets errors at specific fields:

```typescript
validateTree(path, (ctx) => {
  const from = ctx.valueOf(path.from);
  const to = ctx.valueOf(path.to);
  if (from === to) {
    return [
      {
        fieldTree: path.to,
        kind: "same-destination",
        message: "Departure and destination must differ",
      },
    ];
  }
  return undefined;
});
```

### Async/HTTP Validation

```typescript
// Generic async validation
validateAsync(path.username, {
  resource: (ctx) =>
    httpResource<boolean>({
      url: "/api/users/check",
      params: { username: ctx.value() },
    }),
  onResult: (available) =>
    available
      ? undefined
      : {
          kind: "username_taken",
          message: "Username already taken",
        },
});

// HTTP-specific shorthand
validateHttp(path.username, {
  request: (ctx) => ({
    url: "/api/users/check",
    params: { username: ctx.value() },
  }),
  onSuccess: (result: { available: boolean }) => {
    return result.available
      ? undefined
      : {
          kind: "username_taken",
          message: "Username already taken",
        };
  },
  onError: () => ({ kind: "api_error", message: "Server error" }),
});
```

**Note:** Async validation only runs once all synchronous validators pass.

### Zod / Standard Schema Integration

```typescript
import { z } from "zod";

const UserZodSchema = z.object({
  email: z.string().email(),
  age: z.number().min(18).max(120),
});

form(model, (path) => {
  validateStandardSchema(path, UserZodSchema);
});
```

## Nested Forms & Arrays

### apply() - Nested Objects

```typescript
const addressSchema = schema<Address>((path) => {
  required(path.street);
  required(path.city);
});

form(model, (path) => {
  apply(path.address, addressSchema);
});
```

### applyEach() - Array Items

```typescript
const itemSchema = schema<OrderItem>((item) => {
  required(item.product);
  min(item.quantity, 1);
});

form(model, (path) => {
  applyEach(path.items, itemSchema);
});
```

Template for arrays:

```html
@for (item of orderForm.items; track $index) {
<input [formField]="item.product" />
<input type="number" [formField]="item.quantity" />
}
```

Add items by updating the model signal:

```typescript
addItem() {
  this.orderModel.update(order => ({
    ...order,
    items: [...order.items, { product: '', quantity: 1 }]
  }));
}
```

### applyWhen() / applyWhenValue() - Conditional Schemas

```typescript
// Apply based on reactive logic (FieldContext)
applyWhen(
  path.shippingAddress,
  ({ valueOf }) => !valueOf(path.sameAsBilling),
  addressSchema,
);

// Apply based on value predicate (type-narrowing support)
applyWhenValue(
  path,
  (flight) => flight.delayed,
  (delayedFlight) => {
    required(delayedFlight.delay);
    min(delayedFlight.delay, 15);
  },
);
```

## Field State Functions

### disabled(), hidden(), readonly()

```typescript
form(model, (path) => {
  // disabled can return a string (becomes the reason)
  disabled(path.shippingAddress, ({ valueOf }) =>
    valueOf(path.sameAsBilling) ? "Same as billing address" : false,
  );

  hidden(path.vatNumber, ({ valueOf }) => valueOf(path.country) !== "DE");

  readonly(path.orderId);
});
```

**Important:** Non-interactive fields (hidden, disabled, readonly) do NOT contribute to parent validation, touched, or dirty state.

Template:

```html
@if (!form.vatNumber().hidden()) {
<input [formField]="form.vatNumber" />
}
```

### debounce()

```typescript
form(model, (path) => {
  debounce(path.searchTerm, 300); // 300ms delay
});
```

## Form Submission

```typescript
async save() {
  await submit(this.userForm, async (form) => {
    try {
      await this.api.saveUser(form().value());
      return undefined; // Success - no errors
    } catch (error) {
      // Return errors targeted at specific fields
      return [{
        fieldTree: form.email,
        kind: 'server_error',
        message: 'Email already exists'
      }];
    }
  });
}
```

```html
<button [disabled]="userForm().submitting()">
  @if (userForm().submitting()) { Saving... } @else { Save }
</button>
```

## Metadata System

```typescript
import {
  createMetadataKey,
  metadata,
  REQUIRED,
  MIN_LENGTH,
} from "@angular/forms/signals";

// Read built-in metadata
const isRequired = form.password().metadata(REQUIRED); // boolean | undefined
const minLen = form.password().metadata(MIN_LENGTH); // number | undefined

// Create custom metadata
const HINT = createMetadataKey<string>();

form(model, (path) => {
  metadata(path.email, HINT, () => "Enter your work email");
});
```

Template:

```html
@let hint = form.email().metadata(HINT)?.(); @if (hint) {
<span class="hint">{{ hint }}</span> }
```

Built-in metadata keys: `REQUIRED`, `MIN`, `MAX`, `MIN_LENGTH`, `MAX_LENGTH`, `PATTERN`.

MetadataReducer utilities for aggregation: `MetadataReducer.list()`, `.min()`, `.max()`, `.or()`, `.and()`, `.override`.

## Custom Controls

### FormValueControl Contract

For custom controls that integrate with `[formField]`:

```typescript
import { FormValueControl } from "@angular/forms/signals";

@Component({
  selector: "app-html-editor",
  template: `...`,
})
export class HtmlEditorComponent implements FormValueControl<string> {
  readonly value = model("");
  readonly touched = model(false);
  readonly disabled = input(false);
  readonly readonly = input(false);
}
```

### FormCheckboxControl Contract

For checkbox-style controls:

```typescript
interface FormCheckboxControl extends FormUiControl {
  readonly checked: ModelSignal<boolean>;
  readonly value?: undefined;
}
```

### FORM_FIELD DI Token

Inject to access the FormField directive from within custom controls:

```typescript
import { FORM_FIELD } from '@angular/forms/signals';

constructor(@Optional() @Inject(FORM_FIELD) private formField: FormField<unknown>) {}
```

## Subform Components

```typescript
@Component({
  selector: 'app-address-form',
  imports: [FormField],
  template: `
    <input [formField]="address().street" />
    <input [formField]="address().city" />
  `
})
export class AddressFormComponent {
  address = input.required<FieldTree<Address>>();
}

// Usage in parent
<app-address-form [address]="userForm.address" />
<app-address-form [address]="userForm.billingAddress" />
```

## Error Display

```typescript
// Field-specific errors
<app-errors [errors]="form.email().errors()" />

// All errors including nested fields
<app-errors [errors]="form().errorSummary()" />
```

Error factory functions for programmatic error creation:

```typescript
requiredError({ message?, fieldTree? })
emailError({ message?, fieldTree? })
minError(min, { message?, fieldTree? })
maxError(max, { message?, fieldTree? })
minLengthError(minLength, { message?, fieldTree? })
maxLengthError(maxLength, { message?, fieldTree? })
patternError(pattern, { message?, fieldTree? })
standardSchemaError(issue, { message?, fieldTree? })
```

## Global Configuration

```typescript
// app.config.ts
import { provideSignalFormsConfig } from "@angular/forms/signals";

export const appConfig = {
  providers: [
    provideSignalFormsConfig({
      classes: {
        "ng-invalid": (state) => state().invalid(),
        "ng-dirty": (state) => state().dirty(),
        "ng-touched": (state) => state().touched(),
      },
    }),
  ],
};
```

## Model Updates

```typescript
// Replace entire model
this.userModel.set({ name: "Max", email: "max@example.com" });

// Partial update via signal
this.userModel.update((prev) => ({ ...prev, email: "new@email.de" }));

// Single field via FieldTree
this.userForm.email().value.set("new@email.de");
```

## FieldContext Utilities

Available in `LogicFn` callbacks (validators, disabled, hidden, etc.):

```typescript
validate(path.field, (ctx) => {
  ctx.value(); // Current field value (Signal)
  ctx.valueOf(path.otherField); // Value of another field
  ctx.stateOf(path.otherField); // FieldState of another field
  ctx.fieldTreeOf(path.nested); // FieldTree of a nested path
  ctx.pathKeys; // Signal<readonly string[]> for dynamic keys
});
```

## Performance Notes

- Works with `ChangeDetectionStrategy.OnPush`
- Fully compatible with zoneless change detection
- Signals enable fine-grained reactivity (only affected UI re-renders)
- Schema functions should be kept in separate files for reusability

## Boundaries

**Always:**

- Import from `@angular/forms/signals` (not `@angular/forms`)
- Use `FormField` directive for template bindings (not `formControl`/`formGroup`)
- Use `schema()` for reusable validation across components
- Use `LogicFn` for reactive conditional logic inside schemas
- Use `validateTree()` for cross-field validation targeting specific fields
- Handle `pending()` state in templates for async validators

**Never:**

- Mix `@angular/forms` (ReactiveFormsModule) directives with signal forms directives
- Assume `valid()` equals `!invalid()` (pending state exists)
- Put reactive logic directly in the schema function body (use `when`/`LogicFn`)
- Use signal forms in production without acknowledging the experimental status

**References:**

- Official docs: <https://angular.dev/guide/forms/signals>
- Import: `@angular/forms/signals`
-
