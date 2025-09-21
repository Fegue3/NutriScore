// @ts-check
import eslint from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules', 'dist'] },

  // JS base
  eslint.configs.recommended,

  // TS (SEM type-check)
  ...tseslint.configs.recommended, // <-- NÃO usar os *TypeChecked*

  {
    files: ['**/*.ts'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: { tsconfigRootDir: import.meta.dirname },
      sourceType: 'commonjs',
      globals: { ...globals.node, ...globals.jest },
    },
    plugins: { '@typescript-eslint': tseslint.plugin },
    rules: {
      // qualidade que interessa no dia-a-dia
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        destructuredArrayIgnorePattern: '^_', // para _dto, etc.
      }],
      '@typescript-eslint/no-explicit-any': 'off',

      // desliga a família “no-unsafe-*” (só existe no preset type-checked)
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      '@typescript-eslint/no-floating-promises': 'warn',
    },
  }
);
