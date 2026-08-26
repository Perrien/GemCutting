# A Picked Corner Can Never Be Written As `tcp`

Status: untriaged
Filed: 2026-08-26

The meet-picking rule that writes a picked corner as `tcp` when it is the side's axial point and that
side's datum is free can never fire: the kernel reports an axial point on a side only once an earlier
tier there has crossed the axis, and crossing the axis is exactly what claims that side's free datum.
Every picked corner therefore writes the three-facet `vertex` triple, which is correct behaviour but
leaves the `tcp` arm unreachable — either the question is asked the wrong way round, or the arm should
go.
