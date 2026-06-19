from __future__ import annotations

from .models import RiskLevel


def requires_typed_confirmation(risk: RiskLevel) -> bool:
    return risk == RiskLevel.HIGH


def can_auto_clean(risk: RiskLevel, *, yes_safe: bool) -> bool:
    return risk == RiskLevel.SAFE and yes_safe
