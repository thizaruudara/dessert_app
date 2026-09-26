import 'package:cloud_firestore/cloud_firestore.dart';

class DailyPhysicsInsightModel {
  final bool isCustom;
  final String titleSinhala;
  final String titleEnglish;
  final String unitSinhala;
  final String unitEnglish;
  final String formula;
  final String tipSinhala;
  final String tipEnglish;
  final String topicCode;
  final DateTime? updatedAt;
  final String? updatedBy;

  const DailyPhysicsInsightModel({
    required this.isCustom,
    required this.titleSinhala,
    required this.titleEnglish,
    required this.unitSinhala,
    required this.unitEnglish,
    required this.formula,
    required this.tipSinhala,
    required this.tipEnglish,
    required this.topicCode,
    this.updatedAt,
    this.updatedBy,
  });

  factory DailyPhysicsInsightModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return DailyPhysicsInsightModel.defaultRandom();
    }
    final data = doc.data() as Map<String, dynamic>;
    return DailyPhysicsInsightModel(
      isCustom: data['isCustom'] as bool? ?? false,
      titleSinhala: data['titleSinhala'] as String? ?? '',
      titleEnglish: data['titleEnglish'] as String? ?? '',
      unitSinhala: data['unitSinhala'] as String? ?? '',
      unitEnglish: data['unitEnglish'] as String? ?? '',
      formula: data['formula'] as String? ?? '',
      tipSinhala: data['tipSinhala'] as String? ?? '',
      tipEnglish: data['tipEnglish'] as String? ?? '',
      topicCode: data['topicCode'] as String? ?? 'topic_physics_general',
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isCustom': isCustom,
      'titleSinhala': titleSinhala.trim(),
      'titleEnglish': titleEnglish.trim(),
      'unitSinhala': unitSinhala.trim(),
      'unitEnglish': unitEnglish.trim(),
      'formula': formula.trim(),
      'tipSinhala': tipSinhala.trim(),
      'tipEnglish': tipEnglish.trim(),
      'topicCode': topicCode.trim().isEmpty ? 'topic_physics_general' : topicCode.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  factory DailyPhysicsInsightModel.defaultRandom() {
    return const DailyPhysicsInsightModel(
      isCustom: false,
      titleSinhala: '',
      titleEnglish: '',
      unitSinhala: '',
      unitEnglish: '',
      formula: '',
      tipSinhala: '',
      tipEnglish: '',
      topicCode: 'topic_physics_general',
    );
  }

  DailyPhysicsInsightModel copyWith({
    bool? isCustom,
    String? titleSinhala,
    String? titleEnglish,
    String? unitSinhala,
    String? unitEnglish,
    String? formula,
    String? tipSinhala,
    String? tipEnglish,
    String? topicCode,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return DailyPhysicsInsightModel(
      isCustom: isCustom ?? this.isCustom,
      titleSinhala: titleSinhala ?? this.titleSinhala,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      unitSinhala: unitSinhala ?? this.unitSinhala,
      unitEnglish: unitEnglish ?? this.unitEnglish,
      formula: formula ?? this.formula,
      tipSinhala: tipSinhala ?? this.tipSinhala,
      tipEnglish: tipEnglish ?? this.tipEnglish,
      topicCode: topicCode ?? this.topicCode,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Curated A/L Physics Concept Presets Bank
  static const List<DailyPhysicsInsightModel> presetBank = [
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'කාර්යය-ශක්ති ප්‍රමේයය',
      titleEnglish: 'Work-Energy Theorem & Friction Losses',
      unitSinhala: 'යාන්ත්‍ර විද්‍යාව',
      unitEnglish: 'Mechanics',
      formula: 'W_net  =  ΔK  =  ½ m v²  -  ½ m u²',
      tipSinhala: 'ආනත තලයක චලිතයේදී ඝර්ෂණයට එරෙහි කාර්යය (W_f = -f · s) යාන්ත්‍රික ශක්ති සමීකරණයට පෙර වෙන්ව සලකා බලන්න.',
      tipEnglish: 'Always compute work done against friction W_f = -f · s separately before equating mechanical energy at the base of an incline.',
      topicCode: 'topic_work_energy',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'වක්‍ර මාර්ගවල බැංකු නැංවීම',
      titleEnglish: 'Banking of Roads & Circular Motion',
      unitSinhala: 'වෘත්ත චලිතය',
      unitEnglish: 'Circular Motion',
      formula: 'tan θ  =  v² / (r · g)',
      tipSinhala: 'ඝර්ෂණය රහිත උපරිම ආරක්ෂිත ප්‍රවේගය (v) සඳහා අභිකේන්ද්‍ර බලය සැපයෙන්නේ අභිලම්භ ප්‍රතික්‍රියාවේ තිරස් සංරචකය (R sin θ) මගිනි.',
      tipEnglish: 'For frictionless optimal banking speed v, the centripetal force is provided solely by the horizontal normal component R sin θ.',
      topicCode: 'topic_circular_motion',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'ඩොප්ලර් ආචරණය',
      titleEnglish: 'Doppler Effect in Sound Waves',
      unitSinhala: 'තරංග හා දෝලන',
      unitEnglish: 'Waves & Sound',
      formula: 'f\'  =  f₀ [ (v ± v₀) / (v ∓ v_s) ]',
      tipSinhala: 'ප්‍රභවය සහ නිරීක්ෂකයා එකිනෙකා වෙත ළඟා වන විට සංඛ්‍යාතය වැඩි වන බව (f\' > f₀) ලකුණු තේරීමේදී මතක තබා ගන්න.',
      tipEnglish: 'Apparent frequency increases when source and observer approach each other, and decreases when moving apart.',
      topicCode: 'topic_doppler_effect',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'ලෙන්ස්ගේ නියමය සහ වි.ගා.බ. ප්‍රේරණය',
      titleEnglish: "Lenz's Law & Faraday Induction",
      unitSinhala: 'විද්‍යුත් චුම්භකත්වය',
      unitEnglish: 'Electromagnetism',
      formula: 'ε  =  - N ( ΔΦ / Δt )',
      tipSinhala: 'සෘණ ලකුණෙන් දැක්වෙන්නේ ප්‍රේරිත ධාරාව සැමවිටම එය ඇතිවීමට හේතු වූ චුම්භක ස්‍රාව වෙනසට විරුද්ධ වන බවයි (ශක්ති සංස්ථිති නියමය).',
      tipEnglish: 'The negative sign indicates induced current magnetic field opposes the original flux change (Conservation of Energy).',
      topicCode: 'topic_lenz_law',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'වියෝග ප්‍රවේගය (මිදීමේ ප්‍රවේගය)',
      titleEnglish: 'Gravitational Escape Velocity',
      unitSinhala: 'ගුරුත්වාකර්ෂණ ක්ෂේත්‍ර',
      unitEnglish: 'Gravitational Fields',
      formula: 'v_e  =  √( 2 G M / R )  =  √( 2 g R )',
      tipSinhala: 'වියෝග ප්‍රවේගය ප්‍රක්ෂේපිත වස්තුවේ ස්කන්ධය හෝ විදින කෝණය මත රඳා නොපවතී; එය ග්‍රහලෝකයේ ස්කන්ධය හා අරය මත පමණක් රඳා පවතී.',
      tipEnglish: 'Escape velocity is independent of projectile mass and angle; it depends solely on the planet mass and radius.',
      topicCode: 'topic_escape_velocity',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'ධාරිත්‍රකයක ගබඩා වන ශක්තිය',
      titleEnglish: 'Electrostatic Energy in Capacitors',
      unitSinhala: 'ස්ථිති විද්‍යුතය',
      unitEnglish: 'Electrostatics',
      formula: 'U  =  ½ C V²  =  ½ Q V  =  ½ Q² / C',
      tipSinhala: 'බැටරියෙන් සපයන ශක්තිය (Q V) වන අතර, ඉන් හරියටම අඩක් ප්‍රතිරෝධ මගින් තාපය ලෙස හානි වී ඉතිරි අර්ධය (½ Q V) පමණක් විද්‍යුත් ක්ෂේත්‍රයේ ගබඩා වේ.',
      tipEnglish: 'The charging source delivers work W = QV, but exactly 50% is dissipated as thermal loss, leaving U = ½QV in the capacitor field.',
      topicCode: 'topic_capacitors',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'තාපගති විද්‍යාවේ පළමු නියමය',
      titleEnglish: 'First Law of Thermodynamics',
      unitSinhala: 'තාප භෞතික විද්‍යාව',
      unitEnglish: 'Thermal Physics',
      formula: 'ΔQ  =  ΔU  +  ΔW  (ΔW = P ΔV)',
      tipSinhala: 'සමපරිමා ක්‍රියාවලිවලදී පරිමාව වෙනස් නොවන බැවින් ΔW = 0 වන අතර ලබාදෙන සියලු තාපය අභ්‍යන්තර ශක්තිය වැඩිකරයි (ΔQ = ΔU).',
      tipEnglish: 'In isochoric processes ΔW = 0 since volume is constant, so all absorbed heat increases internal energy ΔQ = ΔU.',
      topicCode: 'topic_thermodynamics',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'ප්‍රකාශ විද්‍යුත් ආචරණය',
      titleEnglish: 'Photoelectric Effect & Photons',
      unitSinhala: 'නූතන භෞතික විද්‍යාව',
      unitEnglish: 'Modern Physics',
      formula: 'h f  =  Φ  +  ½ m v_max²  =  Φ  +  e V_s',
      tipSinhala: 'නැවැත්වීමේ විභවය (V_s) රඳා පවතින්නේ ආලෝකයේ සංඛ්‍යාතය (f) මත පමණි; ආලෝක තීව්‍රතාව වැඩි කළද V_s වෙනස් නොවේ.',
      tipEnglish: 'Stopping potential V_s depends solely on frequency f and metal work function Φ, never on incident light intensity.',
      topicCode: 'topic_photoelectric',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'බර්නූලිගේ මූලධර්මය',
      titleEnglish: "Bernoulli's Principle & Fluid Flow",
      unitSinhala: 'තරල විද්‍යාව',
      unitEnglish: 'Hydrodynamics',
      formula: 'P  +  ½ ρ v²  +  ρ g h  =  Constant',
      tipSinhala: 'තිරස් නලයක ද්‍රව ප්‍රවේගය (v) වැඩි වන සිහින් ස්ථානවල පීඩනය (P) අඩුවේ (Venturi ආචරණය).',
      tipEnglish: 'For horizontal streamline flow, locations with higher velocity experience lower fluid pressure (Venturi effect).',
      topicCode: 'topic_bernoulli',
    ),
    DailyPhysicsInsightModel(
      isCustom: true,
      titleSinhala: 'පොටෙන්ෂියෝමීටරය හා අභ්‍යන්තර ප්‍රතිරෝධය',
      titleEnglish: 'Potentiometer & Internal Resistance',
      unitSinhala: 'ධාරා විද්‍යුතය',
      unitEnglish: 'Current Electricity',
      formula: 'r  =  R [ ( l₁ - l₂ ) / l₂ ]',
      tipSinhala: 'සමතුලිත අවස්ථාවේදී කෝෂයෙන් ධාරාවක් නොගලා යන බැවින් අග්‍රස්ථ විභව අන්තරය වෙනුවට නිවැරදිම විද්‍යුත් ගාමක බලය (EMF) මැනේ.',
      tipEnglish: 'At balance point zero current flows through the galvanometer, measuring the true EMF without internal resistance voltage drops.',
      topicCode: 'topic_potentiometer',
    ),
  ];
}
