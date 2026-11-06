Locales = Locales or {}

Locales['en'] = {
    -- Header & Common
    ['ui_title'] = 'Custom Reticle Studio',
    ['ui_subtitle'] = 'Multi-Layer Builder & Text Share Code',
    ['ui_close'] = 'Close (ESC)',
    ['ui_reset'] = 'Reset',
    ['ui_save_preset'] = 'Save Preset',
    ['ui_apply_close'] = 'Apply & Close',

    -- Tabs
    ['tab_standard'] = 'Standard Slots (4)',
    ['tab_layers'] = 'Custom Layers (Max 6)',
    ['tab_display'] = 'Display & Behavior',
    ['tab_presets'] = 'Presets & Share',

    -- Preview & Backgrounds
    ['preview_title'] = 'Zoom Preview (Live Center Reticle Active)',
    ['bg_transparent'] = 'Live Game',
    ['bg_day'] = 'Day Sky',
    ['bg_night'] = 'Night',
    ['bg_urban'] = 'Urban',
    ['label_global_scale'] = 'Global Scale (%)',
    ['label_global_opacity'] = 'Global Opacity (%)',

    -- Standard 4 Slots
    ['slot_dot'] = 'Center Dot',
    ['slot_inner'] = 'Inner Lines',
    ['slot_outer'] = 'Outer Lines',
    ['slot_circle'] = 'Circle / Ring',

    -- Parameters
    ['param_enabled'] = 'Enabled',
    ['param_shape'] = 'Shape',
    ['param_color'] = 'Color',
    ['param_opacity'] = 'Opacity',
    ['param_size'] = 'Size / Length',
    ['param_length'] = 'Line Length',
    ['param_thickness'] = 'Thickness',
    ['param_gap'] = 'Center Gap',
    ['param_radius'] = 'Radius',
    ['param_arc'] = 'Arc Angle (°)',
    ['param_angle'] = 'Spread Angle (°)',
    ['param_rotation'] = 'Rotation (°)',
    ['param_offset_x'] = 'Offset X',
    ['param_offset_y'] = 'Offset Y',
    ['param_t_style'] = 'T-Style (Hide Top)',
    ['param_round_caps'] = 'Rounded Caps',
    ['param_outline'] = 'Outline',
    ['param_outline_width'] = 'Outline Width',
    ['param_outline_color'] = 'Outline Color',
    ['param_outline_opacity'] = 'Outline Opacity',

    -- Primitive Shapes
    ['shape_circle'] = 'Circle',
    ['shape_square'] = 'Square',
    ['shape_diamond'] = 'Diamond',
    ['shape_ring'] = 'Hollow Ring',
    ['shape_cross'] = 'Cross (+)',
    ['shape_tcross'] = 'T-Cross',
    ['shape_chevron'] = 'Chevron (∧)',
    ['shape_line'] = 'Single Line / Mil-Bar',

    -- Custom Layers
    ['btn_add_layer'] = '+ Add Custom Layer',
    ['layer_empty_hint'] = 'Click "+ Add Custom Layer" to stack up to 6 extra shapes such as Chevrons (∧), Mil-dots, or Rings.',
    ['layer_item_title'] = 'Custom Layer #%{index}',
    ['btn_duplicate_layer'] = 'Clone',
    ['btn_delete_layer'] = 'Delete',

    -- Display Modes
    ['display_mode_title'] = 'Reticle Display Timing',
    ['display_mode_desc'] = 'Choose when the custom reticle is shown in-game (some modes may be restricted by server admins).',
    ['mode_aim_only'] = 'When Aiming Only (ADS)',
    ['mode_aim_only_desc'] = 'Visible only while holding right-click to aim.',
    ['mode_armed'] = 'While Armed (Weapon Drawn)',
    ['mode_armed_desc'] = 'Visible whenever holding a firearm, including hip-fire.',
    ['mode_always'] = 'Always On',
    ['mode_always_desc'] = 'Always visible at the center of the screen.',
    ['mode_off'] = 'Hidden (OFF)',
    ['mode_off_desc'] = 'Temporarily hide the custom reticle.',
    ['mode_locked_badge'] = 'Locked by Server Admin',
    ['opt_hide_on_scope'] = 'Auto-hide while looking through sniper scope',
    ['opt_show_in_fp'] = 'Show while aiming in First-Person (FPS) view',

    -- Share Codes & Presets
    ['share_title'] = 'Text Share Code (RT1 Format)',
    ['share_desc'] = 'Copy your reticle as a compact 1-line text code to share with friends or across servers.',
    ['btn_copy_code'] = 'Copy Code',
    ['btn_import_code'] = 'Import Code',
    ['placeholder_share_code'] = 'Paste share code starting with RT1:...',
    ['preset_save_title'] = 'Save Current Reticle to My Presets',
    ['placeholder_preset_name'] = 'Enter preset name (e.g., Cyan Rifle)',
    ['btn_save_new_preset'] = 'Save New',
    ['btn_overwrite_preset'] = 'Overwrite Selected',
    ['my_presets_title'] = 'My Saved Presets',
    ['builtin_presets_title'] = 'Server Built-in Presets',
    ['preset_empty_hint'] = 'No saved presets yet.',
    ['btn_load'] = 'Load',
    ['btn_copy'] = 'Code',
    ['btn_delete'] = 'Delete',

    -- Messages
    ['msg_code_copied'] = 'Share code copied to clipboard!',
    ['msg_code_imported'] = 'Reticle imported from share code.',
    ['msg_invalid_code'] = 'Invalid share code. Must start with RT1:',
    ['msg_preset_saved'] = 'Saved preset "%{name}".',
    ['msg_preset_deleted'] = 'Preset deleted.',
    ['msg_preset_limit'] = 'Maximum preset limit (%{max}) reached.',
    ['msg_reset_done'] = 'Reticle reset to default.',
    ['msg_saved_sync'] = 'Reticle settings saved.',
    ['error_cannot_interact'] = 'Cannot open the reticle editor right now.',
    ['error_invalid_player'] = 'Failed to retrieve player information.',
}
