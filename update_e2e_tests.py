import os
import re

files = [
    '/home/toms/projects/Gem/test/e2e/tier1_feature_test.dart',
    '/home/toms/projects/Gem/test/e2e/tier2_boundary_test.dart',
    '/home/toms/projects/Gem/test/e2e/tier3_combination_test.dart',
    '/home/toms/projects/Gem/test/e2e/tier4_application_test.dart'
]

imports = """
import 'package:gem/presentation/providers/providers.dart';
import '../mocks/mock_oauth_service.dart';
import '../mocks/mock_health_repository.dart';
import '../mocks/mock_agy_process.dart';
"""

def update_file(filepath):
    print(f"Updating {filepath}...")
    with open(filepath, 'r') as f:
        content = f.read()

    # Clean existing imports
    content = content.replace("import '../mocks/mock_oauth_service.dart';", "")
    
    # Add new imports after main.dart import
    main_import = "import 'package:gem/main.dart';"
    if main_import in content:
        content = content.replace(main_import, f"{main_import}\n{imports}")
    else:
        # Prepend to the top
        content = f"{imports}\n{content}"

    # Remove any existing local fakeOAuth declarations to avoid duplicates
    content = content.replace("      final fakeOAuth = FakeOAuthService();", "")

    # Replace ProviderScope calls
    provider_scope_patterns = [
        "const ProviderScope(child: GemApp())",
        "ProviderScope(child: GemApp())",
        "ProviderScope(overrides: [], child: const GemApp())",
        "ProviderScope(overrides: [], child: GemApp())",
        "const ProviderScope(child: const GemApp())",
        "ProviderScope(child: const GemApp())"
    ]
    
    replacement_ps = """ProviderScope(
          overrides: [
            oauthServiceProvider.overrideWithValue(fakeOAuth),
            healthRepositoryProvider.overrideWithValue(fakeHealthRepo),
            agyProcessRunnerProvider.overrideWithValue(fakeAgyRunner),
          ],
          child: const GemApp(),
        )"""

    for pattern in provider_scope_patterns:
        content = content.replace(pattern, replacement_ps)

    # Insert mock declarations at the start of each testWidgets block
    # Match '(tester) async {' or '(tester) async {'
    content = re.sub(
        r'\(tester\)\s*async\s*\{',
        r'(tester) async {\n      final fakeOAuth = FakeOAuthService();\n      final fakeHealthRepo = FakeHealthRepository([]);\n      final fakeAgyRunner = FakeAgyProcessRunner();',
        content
    )

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Finished {filepath}")

for f in files:
    update_file(f)
print("Done all files.")
