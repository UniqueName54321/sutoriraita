import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'genre_packs.dart';

enum GemmellTool {
  discoverEncyclopediaEntries(
    'Discover encyclopedia entries',
    false,
    'Find characters, places, organizations, objects and events that deserve encyclopedia entries in the supplied scope. Compare names and aliases against the existing encyclopedia first; propose additions only for genuinely new entities and updates for existing ones. For each candidate give a canonical name, possible aliases, proposed type, brief evidence quoted from a named scene, and explicit facts separately from inferences. Do not invent facts or claim to have created entries. Return a reviewable list for the author.',
  ),
  proofreadSelection(
    'Proofread selection',
    true,
    'Check spelling and grammar. Separate definite errors from intentional fiction choices.',
  ),
  suggestRewrite(
    'Suggest rewrite',
    true,
    'Suggest up to three rewrites while preserving meaning and voice. Do not insert anything automatically.',
    proseTransformation: true,
  ),
  explainSelection(
    'Explain this passage',
    true,
    'Explain what this passage communicates, including ambiguity or likely reader interpretation.',
  ),
  characterVoice(
    'Check character voice',
    true,
    'Look for possible character-voice drift. Treat contradictions as potentially intentional and explain the evidence.',
  ),
  povLeak(
    'Check for POV leaks',
    true,
    'Identify information the current point-of-view character may not reasonably perceive or know.',
  ),
  factCheck(
    'Fact-check claim',
    true,
    'Extract factual claims, identify what needs verification, and request citations. Do not rely on model memory as proof.',
  ),
  encyclopediaDraft(
    'Draft encyclopedia entry',
    true,
    'Draft a structured encyclopedia entry using only explicit evidence in the selection. Label inferences and unknowns.',
  ),
  structuredFactsFromProse(
    'Extract encyclopedia facts from prose',
    true,
    'Turn the selected prose into proposed encyclopedia structured facts. Group facts by entity, suggest an encyclopedia type and subtype when supported, use existing field names from the supplied encyclopedia where possible, quote brief evidence, and separate explicit facts from inferences. Do not invent missing values.',
  ),
  expandProse(
    'Expand Prose',
    true,
    'Propose an expanded version of the selected passage only. Expansion may introduce repetition, pacing problems, or invented connective material; identify any such risk and do not claim that a higher word count improves the writing.',
    proseTransformation: true,
  ),
  condenseProse(
    'Condense Prose',
    true,
    'Propose a more concise version of the selected passage only without flattening necessary texture, rhythm, characterization, or meaning.',
    proseTransformation: true,
  ),
  rewriteForClarity(
    'Rewrite for Clarity',
    true,
    'Propose a clearer version of the selected passage only. Do not treat deliberate ambiguity, voice, dialect, or unusual grammar as accidental.',
    proseTransformation: true,
  ),
  adjustReadingLevel(
    'Adjust Reading Level',
    true,
    'Propose a version of the selected passage only at the requested reading level without simplifying its facts, characterization, or ideas.',
    proseTransformation: true,
  ),
  ideaQuestions(
    'Idea Bubble: ask questions',
    true,
    'Act as a writing coach. Ask useful questions about the selection without generating story content.',
  ),
  sceneReview(
    'Review current scene',
    false,
    'Review spelling, grammar, clarity, style, continuity risks, and optional improvements in separate sections.',
  ),
  continuity(
    'Continuity Inspector',
    false,
    'Find potential internal contradictions. Say “potential inconsistency,” cite the relevant passage, and allow intentional contradictions.',
  ),
  knowledge(
    'Character Knowledge Checker',
    false,
    'Find moments where a character may know something they have not yet learned. Explain uncertainty.',
  ),
  voiceDrift(
    'Voice Drift',
    false,
    'Check whether dialogue or narration appears internally inconsistent in voice, without treating ordinary variation as an error.',
  ),
  foreshadowing(
    'Foreshadowing Detector',
    false,
    'Identify possible plants, reinforcements, payoffs, and dangling clues. Do not assume every emphasized detail must pay off.',
  ),
  unresolvedSetups(
    'Unresolved Setup Finder',
    false,
    'List apparent promises, hooks, or emphasized details that may still need payoff.',
  ),
  scenePurpose(
    'Scene Purpose',
    false,
    'Describe what this scene accomplishes for plot, character, world, theme, and pacing.',
  ),
  pacing(
    'Pacing Map',
    false,
    'Estimate the balance of action, dialogue, exposition, and reflection, then flag only notable pacing concerns.',
  ),
  readerKnowledge(
    'Reader Knowledge Model',
    false,
    'Summarize what a first-time reader can know, suspect, and cannot yet know after this scene.',
  ),
  mysteryFairness(
    'Mystery Fairness Checker',
    false,
    'Assess whether clues and red herrings are legible and fair without demanding that the solution be obvious.',
  ),
  worldRules(
    'World-rule Checker',
    false,
    'Identify possible conflicts with stated world rules. Distinguish explicit canon from inference.',
  ),
  termConsistency(
    'Name/Term Consistency',
    false,
    'Find likely inconsistent spellings or forms of names and terms. Treat aliases as aliases, not automatic errors.',
  ),
  researchDebt(
    'Research Debt',
    false,
    'Identify factual passages that may require external verification and propose specific research questions.',
  ),
  sensitivityQuestions(
    'Sensitivity Questions',
    false,
    'Raise areas the author may wish to research or seek informed feedback on. Do not claim to adjudicate them.',
  ),
  developmentalReview(
    'Developmental Review',
    false,
    'Give scene-level developmental feedback focused on structure, stakes, motivation, clarity, and reader experience.',
  ),
  ideas(
    'Idea Bubble: possibilities',
    false,
    'Offer several clearly separated possibilities without selecting one or writing them into the manuscript.',
  ),
  storyContinuity(
    'Whole-story Continuity Audit',
    false,
    'Audit the complete manuscript and encyclopedia for potential contradictions, with evidence and uncertainty.',
    requiresPackage: true,
  ),
  storyKnowledge(
    'Whole-story Knowledge Timeline',
    false,
    'Track when major characters learn important facts and identify possible knowledge leaks across scenes.',
    requiresPackage: true,
  ),
  storyForeshadowing(
    'Whole-story Foreshadowing Map',
    false,
    'Map plants, reinforcements, payoffs, dangling clues, and unusually late setup across the manuscript.',
    requiresPackage: true,
  ),
  storyForgottenCharacters(
    'Forgotten Character Detector',
    false,
    'Find characters introduced with apparent importance who disappear or lose narrative function.',
    requiresPackage: true,
  ),
  storyRelationships(
    'Relationship Drift Audit',
    false,
    'Track major relationship changes and identify abrupt or insufficiently supported transitions.',
    requiresPackage: true,
  ),
  storyPacing(
    'Whole-story Pacing Map',
    false,
    'Analyze pacing and scene-function distribution across the complete manuscript.',
    requiresPackage: true,
  ),
  storyDevelopmental(
    'Whole-story Developmental Review',
    false,
    'Review overall structure, stakes, character arcs, clarity, repetition, and reader experience.',
    requiresPackage: true,
  ),
  storyCanon(
    'Canon and Terminology Audit',
    false,
    'Compare manuscript usage against encyclopedia entries and find possible world-rule, name, and terminology inconsistencies.',
    requiresPackage: true,
  ),
  encyclopediaReview(
    'Review encyclopedia entry',
    false,
    'Review this entry for clarity, completeness, internal consistency, and unsupported claims.',
    encyclopediaOnly: true,
  ),
  encyclopediaCanonCheck(
    'Check against encyclopedia canon',
    false,
    'Compare this entry with the rest of the encyclopedia and identify potential contradictions or ambiguous relationships.',
    encyclopediaOnly: true,
  ),
  encyclopediaGaps(
    'Find missing fields and questions',
    false,
    'Identify useful unanswered questions without inventing facts to fill the gaps.',
    encyclopediaOnly: true,
  ),
  encyclopediaRelationships(
    'Map relationships',
    false,
    'Extract explicit and implied relationships between this entry and other encyclopedia entities, citing the supplied context.',
    encyclopediaOnly: true,
  ),
  encyclopediaAliases(
    'Check aliases and terminology',
    false,
    'Find likely aliases, naming variants, and inconsistent terminology without treating alternate forms as separate entities.',
    encyclopediaOnly: true,
  ),
  encyclopediaStructure(
    'Suggest entry structure',
    false,
    'Suggest a clearer CommonMark structure appropriate to this entry type while preserving all established facts.',
    encyclopediaOnly: true,
  ),
  encyclopediaBodyToFacts(
    'Extract structured facts from entry body',
    false,
    'Turn this encyclopedia entry body into proposed structured field values. Use the available field keys and labels supplied in the context, preserve existing facts, cite brief supporting text, clearly separate inference, and do not invent values. Return a concise field-by-field change list for the author to review; do not claim the fields were changed automatically.',
    encyclopediaOnly: true,
  );

  const GemmellTool(
    this.label,
    this.requiresSelection,
    this.instruction, {
    this.requiresPackage = false,
    this.encyclopediaOnly = false,
    this.proseTransformation = false,
  });
  final String label;
  final bool requiresSelection;
  final String instruction;
  final bool requiresPackage;
  final bool encyclopediaOnly;
  final bool proseTransformation;

  String get example => switch (this) {
    discoverEncyclopediaEntries => 'Example: find Mika in this chapter, recognize her nickname, and suggest a character entry with scene evidence.',
    proofreadSelection =>
      'Example: flag “teh door” and explain the correction.',
    suggestRewrite =>
      'Example: offer concise, lyrical, and dialogue-led alternatives.',
    explainSelection =>
      'Example: explain what a deliberately ambiguous line implies.',
    characterVoice => 'Example: note that Sandra sounds unusually formal here.',
    povLeak =>
      'Example: ask how the viewpoint character knows what is behind the door.',
    factCheck =>
      'Example: verify a railway opening date and request reliable citations.',
    encyclopediaDraft =>
      'Example: extract an evidence-backed character card for Dr Webb.',
    structuredFactsFromProse => 'Example: extract Ren’s occupation and Mika’s workplace from a selected scene.',
    expandProse => 'Example: expand a rushed transition while flagging any invented connective detail.',
    condenseProse =>
      'Example: tighten a repetitive paragraph without flattening its joke.',
    rewriteForClarity => 'Example: clarify a difficult sentence while retaining its narrator’s voice.',
    adjustReadingLevel => 'Example: make a selected explanation more accessible without removing its ideas.',
    ideaQuestions =>
      'Example: ask what the character wants without inventing an answer.',
    sceneReview =>
      'Example: separate definite errors from optional stylistic suggestions.',
    continuity =>
      'Example: compare “three weeks ago” with the established 17-day gap.',
    knowledge => 'Example: notice Marcus names Claire’s brother before learning about him.',
    voiceDrift =>
      'Example: compare unusually formal dialogue with the established voice.',
    foreshadowing =>
      'Example: connect the locked basement door to a later implied payoff.',
    unresolvedSetups =>
      'Example: list an emphasized chemical smell with no visible payoff.',
    scenePurpose =>
      'Example: identify the scene’s plot turn and character decision.',
    pacing =>
      'Example: estimate dialogue, action, exposition, and reflection balance.',
    readerKnowledge =>
      'Example: separate what readers know from what they merely suspect.',
    mysteryFairness =>
      'Example: assess whether a reveal has enough discoverable clues.',
    worldRules =>
      'Example: flag magic apparently violating an encyclopedia-defined limit.',
    termConsistency =>
      'Example: compare XyonTech, Xyon Tech, and Xyon Technology.',
    researchDebt =>
      'Example: turn an unsupported technical claim into research questions.',
    sensitivityQuestions =>
      'Example: identify where informed feedback may be worthwhile.',
    developmentalReview =>
      'Example: examine stakes, motivation, structure, and clarity.',
    ideas => 'Example: offer three directions without inserting any into the manuscript.',
    storyContinuity =>
      'Example: reconcile conflicting ages, dates, injuries, and travel times.',
    storyKnowledge => 'Example: show that Marcus uses a name three chapters before learning it.',
    storyForeshadowing => 'Example: connect the basement plant, two reinforcements, and its final payoff.',
    storyForgottenCharacters => 'Example: find Florence vanishing after an apparently important introduction.',
    storyRelationships => 'Example: flag a friendship becoming hostility without an evident transition.',
    storyPacing => 'Example: map a reflective middle against an action-heavy opening and ending.',
    storyDevelopmental => 'Example: assess whether the central arc escalates and resolves coherently.',
    storyCanon => 'Example: compare XyonTech variants and world rules against encyclopedia canon.',
    encyclopediaReview => 'Example: separate established biography details from unclear speculation.',
    encyclopediaCanonCheck => 'Example: notice two entries assigning different founders to the same group.',
    encyclopediaGaps =>
      'Example: ask when a location was abandoned without inventing a date.',
    encyclopediaRelationships => 'Example: map that Mika works at the laundromat and collaborates with Ren.',
    encyclopediaAliases =>
      'Example: recognize XyonTech as an alias rather than a new organization.',
    encyclopediaStructure => 'Example: organize a character entry into role, traits, history, and relationships.',
    encyclopediaBodyToFacts => 'Example: propose Occupation: Night clerk from an established sentence in the entry body.',
  };
}

class GemmellSettings {
  static const tones = <String>[
    'No tone — preserve chatbot personality',
    'Professional',
    'Friendly',
    'Concise',
    'Enthusiastic',
    'Snarky',
  ];
  static const toneIntensities = <int, String>{
    1: 'Very little',
    2: 'A little',
    3: 'Noticeable',
    4: 'Strong',
    5: 'Extremely overboard',
  };
  static const editingStyles = <String>[
    'Preserve the manuscript voice',
    'Light-touch copyedit',
    'Balanced edit',
    'Developmental guidance',
    'Bold rewrite suggestions',
  ];

  GemmellSettings({
    this.enabled = false,
    this.useWizard = true,
    this.name = 'Gemmell McGee',
    this.pronouns = 'he/him',
    this.tone = 'No tone — preserve chatbot personality',
    this.toneIntensity = 3,
    this.editingStyle = 'Preserve the manuscript voice',
    this.proseTransformationEnabled = false,
  });

  bool enabled;
  bool useWizard;
  String name;
  String pronouns;
  String tone;
  int toneIntensity;
  String editingStyle;
  bool proseTransformationEnabled;

  static Future<GemmellSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTone = prefs.getString('gemmell.tone');
    final storedEditingStyle = prefs.getString('gemmell.editingStyle');
    return GemmellSettings(
      enabled: prefs.getBool('gemmell.enabled') ?? false,
      useWizard: prefs.getBool('gemmell.useWizard') ?? true,
      name: prefs.getString('gemmell.name') ?? 'Gemmell McGee',
      pronouns: prefs.getString('gemmell.pronouns') ?? 'he/him',
      tone: tones.contains(storedTone) ? storedTone! : tones.first,
      toneIntensity: (prefs.getInt('gemmell.toneIntensity') ?? 3)
          .clamp(1, 5)
          .toInt(),
      editingStyle: editingStyles.contains(storedEditingStyle)
          ? storedEditingStyle!
          : editingStyles.first,
      proseTransformationEnabled:
          (prefs.getBool('gemmell.proseTransformationEnabled') ?? false) &&
          (prefs.getBool('gemmell.enabled') ?? false),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemmell.enabled', enabled);
    await prefs.setBool('gemmell.useWizard', useWizard);
    await prefs.setString('gemmell.name', name);
    await prefs.setString('gemmell.pronouns', pronouns);
    await prefs.setString('gemmell.tone', tone);
    await prefs.setInt('gemmell.toneIntensity', toneIntensity);
    await prefs.setString('gemmell.editingStyle', editingStyle);
    await prefs.setBool(
      'gemmell.proseTransformationEnabled',
      enabled && proseTransformationEnabled,
    );
  }

  String prompt({
    required GemmellTool tool,
    required String project,
    required String scene,
    required String text,
    String? selection,
    String encyclopedia = '',
    String subjectKind = 'Scene',
    String transformationOptions = '',
  }) {
    final intensity = toneIntensities[toneIntensity] ?? toneIntensities[3]!;
    final personality = tone.startsWith('No tone')
        ? 'Keep your normal conversational personality and response style.'
        : 'Use this assistant tone when speaking to me: $tone. Tone intensity: $toneIntensity/5 — $intensity.';
    final material = tool.requiresSelection ? selection?.trim() ?? '' : text;
    final transformationRules = tool.proseTransformation
        ? '''
PROSE TRANSFORMATION REQUEST
Scope: selected passage only.
Options: ${transformationOptions.trim().isEmpty ? 'Preserve meaning, change wording.' : transformationOptions.trim()}
Preserve voice, facts, POV (point of view), tense, dialogue style, intentional grammatical weirdness, dialect, jokes, contradictions, and characterization unless the request explicitly says otherwise.
Return a proposed rewrite for manual review. Never claim to have replaced or edited the manuscript. Keep the original and proposal clearly distinguishable.
'''
        : '';
    if (tool.requiresPackage) {
      return '''You are assisting with a Sutōrīraitā writing project through Prompt Bridge.
$personality
Assistant identity: $name ($pronouns).
Editing approach: $editingStyle.
Tool: ${tool.label}
Task: ${tool.instruction}

The complete project is attached as a .sutoriraita portable package. It is a ZIP-based container whose sutoriraita.json manifest describes ordered sections, scenes, and encyclopedia entries; prose is stored as Markdown files. Read the attached package before answering. If you cannot access attachments or ZIP contents, say so plainly instead of inventing project facts.

Do not silently rewrite the manuscript. Preserve intentional fiction choices and clearly separate evidence, inference, and uncertainty.

Project: $project''';
    }
    final encyclopediaBlock = encyclopedia.trim().isEmpty
        ? 'No encyclopedia entries are currently available.'
        : '''--- BEGIN ENCYCLOPEDIA SNAPSHOT ---
${encyclopedia.trim()}
--- END ENCYCLOPEDIA SNAPSHOT ---''';
    final materialKind = tool.encyclopediaOnly
        ? 'ENCYCLOPEDIA ENTRY'
        : (tool.requiresSelection ? 'SELECTION' : subjectKind.toUpperCase());
    return '''You are assisting with a Sutōrīraitā writing project through Prompt Bridge.
$personality
Assistant identity: $name ($pronouns).
Editing approach: $editingStyle.
Tool: ${tool.label}
Task: ${tool.instruction}
$transformationRules
Do not silently rewrite the manuscript. Preserve intentional fiction choices such as dialect, unreliable narration, sarcasm, and deliberate contradiction. Clearly separate evidence from inference.

Project: $project
$subjectKind: $scene

--- BEGIN $materialKind ---
$material
--- END $materialKind ---

$encyclopediaBlock''';
  }
}

String gemmellEncyclopediaContext(StoryProject project) {
  if (project.encyclopedia.isEmpty) return '';
  final entries = [...project.encyclopedia]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  final relationTypes = [
    ...GenrePacks.baseRelations,
    for (final pack in GenrePacks.active(project)) ...pack.relations,
  ];
  return entries
      .map((entry) {
        final definitions = GenrePacks.fieldsFor(project, entry);
        final facts = entry.fields.entries
            .map((field) {
              final definition = definitions
                  .where((candidate) => candidate.key == field.key)
                  .firstOrNull;
              final label =
                  definition?.label ?? field.key.replaceFirst('custom:', '');
              return '- **$label:** ${field.value}';
            })
            .join('\n');
        final relations = project.relations
            .where((relation) => relation.fromEntryId == entry.id)
            .map((relation) {
              final target = entries
                  .where((candidate) => candidate.id == relation.toEntryId)
                  .firstOrNull;
              final type = relationTypes
                  .where((candidate) => candidate.id == relation.relationTypeId)
                  .firstOrNull;
              return '- ${type?.label ?? relation.relationTypeId}: ${target?.title ?? relation.toEntryId}';
            })
            .join('\n');
        return '''## ${entry.title}
Aliases: ${entry.aliases.join(', ')}
Type: ${entry.type.label}${entry.subtype == null ? '' : ' / ${entry.subtype}'}
${facts.isEmpty ? 'Structured facts: (none)' : 'Structured facts:\n$facts'}
${relations.isEmpty ? '' : 'Relations:\n$relations\n'}
${entry.content.trim().isEmpty ? '(No freeform description yet.)' : entry.content.trim()}''';
      })
      .join('\n\n');
}
